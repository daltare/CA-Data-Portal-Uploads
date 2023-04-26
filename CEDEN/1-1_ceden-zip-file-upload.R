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
library(here)



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
source(here('start_selenium.R'))



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
            print(glue('uploading ({dataset_name})'))
            Sys.sleep(10)
        }
        t2 <- Sys.time()
        
        upload_time <- t2 - t1
        print(glue('upload complete ({dataset_name}) -- upload time: {round(upload_time,1)} {units(upload_time)}'))  
    }
    
    # go to the next file
    
}



# close server ------------------------------------------------------------
remDr$close()
shell.exec(file = here('Stop.bat')) # this closes the java window
