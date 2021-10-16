# Notes:
# 1. Enter your data.ca.gov portal username in the environment variables for you account, in a variable called 'portal_username'
# 2. Enter your data.ca.gov portal password in the environment variables for you account, in a variable called 'portal_password'


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
library(glue)
library(tictoc)



# enter variables ---------------------------------------------------------
## data portal username and password ----
# portal_username <- Sys.getenv('portal_username') 
# portal_password <- Sys.getenv('portal_password')

### path to data files ----
# data_files_date <- Sys.Date()
# data_files_path <- glue('C:\\David\\_CA_data_portal\\CEDEN\\CEDEN_Datasets\\{data_files_date}\\')

## list files / resources
# zip_resource_id_list <- list(
#     'toxicity' = list(dataset_name = 'surface-water-toxicity-results',
#                       dataset_id = 'ac8bf4c8-0675-4764-92f1-b67bdb187ba1',
#                       data_file = glue('{data_files_path}ToxicityData_{data_files_date}.zip')),
#     'benthic' = list(dataset_name = 'surface-water-benthic-macroinvertebrate-results',
#                      dataset_id = '15349797-6cfc-4ef9-92ab-0ed36512de93',
#                      data_file = glue('{data_files_path}BenthicData_{data_files_date}.zip')),
#     'chemistry' = list(dataset_name = 'surface-water-chemistry-results',
#                        dataset_id = '18dada05-3877-4520-906e-f16038d648b6',
#                        data_file = glue('{data_files_path}WaterChemistryData_{data_files_date}.zip')),
#     'habitat' = list(dataset_name = 'surface-water-habitat-results',
#                      dataset_id = '24d9b91d-5f7e-471f-8720-849cceabe0ba',
#                      data_file = glue('{data_files_path}HabitatData_{data_files_date}.zip')),
#     'tissue' = list(dataset_name = 'surface-water-aquatic-organism-tissue-sample-results',
#                     dataset_id = '4c38ae52-9fe2-4da0-9d0f-ea4b2203a41f',
#                     data_file = glue('{data_files_path}TissueData_{data_files_date}.zip'))
# )



# set up selenium (automated browser) -------------------------------------
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




# load files to portal ----------------------------------------------------

## navigate to data.ca.gov log in page and log in ----
login_url <- 'https://data.ca.gov/user/login'
remDr$navigate(login_url)
webElem <- remDr$findElement(using = 'id', value = 'field-login')
webElem$sendKeysToElement(list(portal_username))
webElem <- remDr$findElement(using = 'id', value = 'field-password')
webElem$sendKeysToElement(list(portal_password))
webElem <- remDr$findElement(using = 'css selector', value = 'button.btn.btn-primary')
webElem$clickElement()


## loop through all resources and enter data ----
for (id_number in seq_along(names(zip_resource_id_list))) {
    # id_number <- 1
    data_resource_id <- zip_resource_id_list[[id_number]][['dataset_id']]
    dataset_name <- zip_resource_id_list[[id_number]][['dataset_name']]
    data_file <- zip_resource_id_list[[id_number]][['data_file']]
    
    ### navigate to resource editor page ----
    edit_url <- paste0('https://data.ca.gov/dataset/', dataset_name, '/resource_edit/', data_resource_id)
    remDr$navigate(edit_url)
    Sys.sleep(3)
    
    # click the 'Remove' button (to remove the old version of the file)
    webElem <- remDr$findElement(using = 'css selector', value = paste0('.btn-remove-url'))
    webElem$clickElement()
    Sys.sleep(3)
    
    # enter the path of the new file to be uploaded
    webElem <- remDr$findElement(using = 'css selector', value = paste0('#field-image-upload'))
    # webElem$clickElement()
    webElem$sendKeysToElement(list(data_file))
    Sys.sleep(3)
    
    # click the 'Update Resource' button to upload the new file
    webElem <- remDr$findElement(using = 'css selector', value = 'button.btn.btn-primary')
    webElem$clickElement()
    
    # wait until the upload is complete before going to the next step (can't navigate away from the page while files are being uploaded)
    # NOTE: maybe also use ?setImplicitWaitTimeout()
    ### see: https://stackoverflow.com/questions/27080920/how-to-check-if-page-finished-loading-in-rselenium
    ### see: https://stackoverflow.com/questions/11256732/how-to-handle-windows-file-upload-using-selenium-webdriver
    {
        i <- 0
        t1 <- Sys.time()
        while(remDr$getCurrentUrl() == edit_url & i <= 120) { 
            print('uploading')
            Sys.sleep(10)
        }
        t2 <- Sys.time()
        
        upload_time <- t2 - t1
        print(glue('upload complete -- upload time: {round(upload_time,1)} {units(upload_time)}'))  
    }
    
    # go to the next file
    
}



# close server ------------------------------------------------------------
remDr$close()
shell.exec(file = 'Stop.bat') # this closes the java window
