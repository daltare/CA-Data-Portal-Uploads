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
# data_files_path <- glue('C:\\David\\_CA_data_portal\\CEDEN\\{data_files_date}\\')
# data_dictionaries_path <- here('data_dictionaries', 'data_dictionary_conversion')
# parquet_file_save_location <- paste0(data_files_path, 'parquet_datasets')

## list files / resources
# parquet_resource_id_list <- list(
#     'toxicity' = list(source_file_name = 'ToxicityData',
#                       data_dictionary = 'toxicity\\CEDEN_Toxicity_Data_Dictionary.xlsx',
#                       portal_dataset_name = 'surface-water-toxicity-results',
#                       portal_dataset_id = 'a6c91662-d324-43c2-8166-a94dddd22982',
#                       parquet_data_file = glue('ToxicityData_Parquet_{data_files_date}')),
#     'benthic' = list(source_file_name = 'BenthicData',
#                      data_dictionary = 'benthic\\CEDEN_Benthic_Data_Dictionary.xlsx',
#                      portal_dataset_name = 'surface-water-benthic-macroinvertebrate-results',
#                      portal_dataset_id = 'eb61f9a1-b1c6-4840-99c7-420a2c494a43',
#                      parquet_data_file = glue('BenthicData_Parquet_{data_files_date}')),
#     'chemistry' = list(source_file_name = 'WaterChemistryData',
#                             data_dictionary = 'water_chemistry\\CEDEN_Chemistry_Data_Dictionary.xlsx',
#                             portal_dataset_name = 'surface-water-chemistry-results',
#                             portal_dataset_id = 'f4aa224d-4a59-403d-aad8-187955aa2e38',
#                             parquet_data_file = glue('WaterChemistryData_Parquet_{data_files_date}')),
#     'tissue' = list(source_file_name = 'TissueData',
#                     data_dictionary = 'tissue\\CEDEN_Tissue_Data_Dictionary.xlsx',
#                     portal_dataset_name = 'surface-water-aquatic-organism-tissue-sample-results',
#                     portal_dataset_id = 'dea5e450-4196-4a8a-afbb-e5eb89119516',
#                     parquet_data_file = glue('TissueData_Parquet_{data_files_date}')),
#     'habitat' = list(source_file_name = 'HabitatData',
#                      data_dictionary = 'habitat\\CEDEN_Habitat_Data_Dictionary.xlsx',
#                      portal_dataset_name = 'surface-water-habitat-results',
#                      portal_dataset_id = '0184c4d0-1e1d-4a33-92ad-e967b5491274',
#                      parquet_data_file = glue('HabitatData_Parquet_{data_files_date}'))
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

## check for open port ----
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
Sys.sleep(3)


## loop through all resources and upload file ----
for (id_number in seq_along(names(parquet_resource_id_list))) {
    gc()
    # id_number <- 4
    data_resource_id <- parquet_resource_id_list[[id_number]][['portal_dataset_id']]
    dataset_name <- parquet_resource_id_list[[id_number]][['portal_dataset_name']]
    data_file <- parquet_resource_id_list[[id_number]][['parquet_data_file']]
    data_file_path <- glue('{parquet_file_save_location}\\{data_file}.zip')
    
    print(glue('Uploading: {data_file}'))

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
    webElem$sendKeysToElement(list(data_file_path))
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
        print(glue('Upload Complete -- upload time: {round(upload_time,1)} {units(upload_time)}')) 
        print(glue('File Uploaded: {data_file}'))
    }
    
    # go to the next file
    
}



# close server ------------------------------------------------------------
remDr$close()
shell.exec(file = 'Stop.bat') # this closes the java window
