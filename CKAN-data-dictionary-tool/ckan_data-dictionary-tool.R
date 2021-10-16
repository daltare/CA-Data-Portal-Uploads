# Notes:
# 1. The dictionary file should be an excel file with the header names 'column', 'label', 'type', and eithter 'description' or 'description_combined' (it may also have other colums as well - doesn't matter)
# 2. The order of the fields listed in the dictionary MUST match the order of the columns in the dataset
# 3. Make sure the fields defined as numeric or timestamp in the dictionary are correctly formatted in the dataset (missing numeric values must be 'NaN', dates must be in ISO format and missing dates should be an empty text string i.e. '')
# 4. Put the dictionary file in the same location as this script file
# 5. Enter your data.ca.gov portal username in the environment variables for you account, in a variable called 'portal_username'
# 6. Enter your data.ca.gov portal password in the environment variables for you account, in a variable called 'portal_password'
# 7. Note that the 'type' field in the portal doesn't update until the datastore is updated (go to 'Manage', 'Data Store', click 'Upload to DataStore')


# load packages -----------------------------------------------------------
library(RSelenium)
library(methods) # it seems that this needs to be called explicitly to avoid an error for some reason
library(XML)
library(dplyr)
library(janitor)
library(readr)
library(lubridate)
library(readxl)
library(ckanr)
library(binman)
library(wdman)
library(stringr)
library(magrittr)
library(pingr)



# enter variables ---------------------------------------------------------
dictionary_filename <- 'Data_Dictionary_Template.xlsx'
dictionary_fields <- c('column', 'type', 'label', 'description') # has to be in order: Column, Type, Label, Description
dataset_name <- 'surface-water-electronic-self-monitoring-report-esmr-data'
data_resource_id_list <-  list('2021' = '28d3a164-7cec-4baf-9b11-7a9322544cd6',
                               '2020' = '4fa56f3f-7dca-4dbd-bec4-fe53d5823905',
                               '2019' = '2eaa2d55-9024-431e-b902-9676db949174',
                               '2018' = 'bb3b3d85-44eb-4813-bbf9-ea3a0e623bb7',
                               '2017' = '44d1f39c-f21b-4060-8225-c175eaea129d',
                               '2016' = 'aacfe728-f063-452c-9dca-63482cc994ad',
                               '2015' = '81c399d4-f661-4808-8e6b-8e543281f1c9',
                               '2014' = 'c0f64b3f-d921-4eb9-aa95-af1827e5033e',
                               '2013' = '8fefc243-9131-457f-b180-144654c1f481',
                               '2012' = '67fe1c01-1c1c-416a-92e1-ee8437db615a',
                               '2011' = 'c495ca93-6dbe-4b23-9d17-797127c28914',
                               '2010' = '4eb833b3-f8e9-42e0-800e-2b1fe1e25b9c',
                               '2009' = '3607ae5c-d479-4520-a2d6-3112cf92f32f',
                               '2008' = 'c0e3c8be-1494-4833-b56d-f87707c9492c',
                               '2007' = '7b99f591-23ac-4345-b645-9adfaf5873f9',
                               '2006' = '763e2c90-7b7d-412e-bbb5-1f5327a5f84e'
)



# 1 - get data dictionary -------------------------------------------------
# get the info to fill out the data dictionary 
df_dictionary <- read_excel(dictionary_filename) %>% 
    clean_names() %>% 
    select(all_of(dictionary_fields))
# df_dictionary <- df_dictionary %>%
#     mutate(type = tolower(type)) %>%
#     mutate(column = tolower(column))
# check the fields defined as numeric and timestamp
# z_numeric_fields <- df_dictionary %>% filter(type == 'numeric') %>% select(column)
# identical(z_numeric_fields$column, fields_numeric) # should be TRUE
# z_timestamp_fields <- df_dictionary %>% filter(type == 'timestamp') %>% select(column)
# identical(z_timestamp_fields$column, fields_dates) # should be TRUE



# 2 - set up selenium (automated browser) ---------------------------------
## Note - for more information / examples on how the RSelenium package works, see:
# https://stackoverflow.com/questions/35504731/specify-download-folder-in-rselenium        
# https://cran.r-project.org/web/packages/RSelenium/vignettes/RSelenium-basics.html
# https://stackoverflow.com/questions/32123248/submitting-form-from-r-to-mixed-html-and-javascript
# https://github.com/ropensci/RSelenium/issues/121


## define chrome browser options for the Selenium session ----
eCaps <- list( 
    chromeOptions = 
        list(prefs = list(
            "profile.default_content_settings.popups" = 0L,
            "download.prompt_for_download" = FALSE,
            "download.default_directory" = gsub(pattern = '/', replacement = '\\\\', x = getwd()) # download.dir
        )
        )
)

## check for open port ----
for (port_check in 4567L:4577L) {
    port_test <- ping_port(destination = 'localhost', port = port_check)
    # print(all(is.na(port_test)))
    if (all(is.na(port_test)) == TRUE) {
        port_use <- port_check
        break
    }
}

## get drivers ----
selenium(jvmargs = 
             c("-Dwebdriver.chrome.verboseLogging=true"), 
         retcommand = TRUE,
         port = port_use)
Sys.sleep(5)

## get current version of chrome browser ----
chrome_browser_version <-
    system2(command = "wmic",
            args = 'datafile where name="C:\\\\Program Files (x86)\\\\Google\\\\Chrome\\\\Application\\\\chrome.exe" get Version /value',
            stdout = TRUE,
            stderr = TRUE) %>%
    str_extract(pattern = "(?<=Version=)(\\d+\\.){3}")

## get available chrome drivers ----
chrome_driver_versions <- list_versions("chromedriver")

## match driver / version ----
chrome_driver_current <- chrome_browser_version %>%
    extract(!is.na(.)) %>%
    str_replace_all(pattern = "\\.",
                    replacement = "\\\\.") %>%
    paste0("^",  .) %>%
    str_subset(string = dplyr::last(chrome_driver_versions)) %>%
    as.numeric_version() %>%
    max() %>%
    as.character()

## re-check for open port ----
for (port_check in 4567L:4577L) {
    port_test <- ping_port(destination = 'localhost', port = port_check)
    # print(all(is.na(port_test)))
    if (all(is.na(port_test)) == TRUE) {
        port_use <- port_check
        break
    }
}

## set up selenium with the current chrome version ----
selCommand <- selenium(jvmargs = 
                           c("-Dwebdriver.chrome.verboseLogging=true"), 
                       retcommand = TRUE,
                       chromever = chrome_driver_current,
                       port = port_use)

## write selenium specifications to batch file ----
writeLines(selCommand, 
           'Start_Server.bat')
Sys.sleep(5) #### wait a few seconds

## start server ----
shell.exec('Start_Server.bat')
Sys.sleep(10) #### wait a few seconds

## open connection ----
remDr <- remoteDriver(port = port_use, # 4567L, 
                      browserName = "chrome", 
                      extraCapabilities = eCaps)
Sys.sleep(10) #### wait a few seconds
remDr$open()



# 3 - enter dictionary data to portal -----------------------------------------
## get portal username and password ----
portal_username <- Sys.getenv('portal_username') 
portal_password <- Sys.getenv('portal_password')

## navigate to data.ca.gov login page and log in ----
login_url <- 'https://data.ca.gov/user/login'
remDr$navigate(login_url)
webElem <- remDr$findElement(using = 'id', value = 'field-login')
webElem$sendKeysToElement(list(portal_username))
webElem <- remDr$findElement(using = 'id', value = 'field-password')
webElem$sendKeysToElement(list(portal_password))
webElem <- remDr$findElement(using = 'css selector', value = 'button.btn.btn-primary')
webElem$clickElement()

## loop through all resources and enter data ----
for (id_number in seq_along(names(data_resource_id_list))) {
    data_resource_id <- data_resource_id_list[[id_number]]
    
    ### navigate to data dictionary editor page ----
    dictionary_url <- paste0('https://data.ca.gov/dataset/', dataset_name, '/dictionary/', data_resource_id)
    remDr$navigate(dictionary_url)
    
    ### loop through all fields defined in the dictionary / enter into data dictionary interface on the portal ----
    for (i in seq(nrow(df_dictionary))) {
        #### enter field type ----
        webElem <- remDr$findElement(using = 'id', value = paste0('info__', i, '__type_override'))
        webElem$sendKeysToElement(list(df_dictionary[[i, dictionary_fields[2]]]))
        #### enter label ----
        webElem <- remDr$findElement(using = 'id', value = paste0('field-f', i, 'label'))
        webElem$clearElement()
        webElem$sendKeysToElement(list(df_dictionary[[i, dictionary_fields[3]]]))
        #### enter description ----
        webElem <- remDr$findElement(using = 'id', value = paste0('field-d', i, 'notes'))
        webElem$clearElement()
        webElem$sendKeysToElement(list(df_dictionary[[i, dictionary_fields[4]]]))
    }
    
    ### click save button ----
    webElem <- remDr$findElement(using = 'css selector', value = 'button.btn.btn-primary')
    webElem$clickElement()
}



# 4 - close server ------------------------------------------------------------
remDr$close()
shell.exec(file = 'Stop.bat') # this closes the java window
