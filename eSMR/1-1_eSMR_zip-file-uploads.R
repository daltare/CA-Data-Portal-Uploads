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
# download_dir <- 'C:\\David\\_CA_data_portal\\eSMR\\'
# file_name <- 'esmr_analytical_export'
# parquet_directory <- glue('{file_name}_years-{min(years_download)}-{max(years_download)}_parquet_{Sys.Date()}')
# data_files_date <- Sys.Date()

# data_files_date <- Sys.Date()
# data_files_path <- glue('C:\\David\\_CA_data_portal\\CEDEN\\CEDEN_Datasets\\{data_files_date}\\')

## list files / resources
# zip_resource_id_list <- list(
#     'ziped_csv' = list(dataset_name = 'water-quality-effluent-electronic-self-monitoring-report-esmr-data',
#                       dataset_id = '5901c092-20e9-4614-b22b-37ee1e5c29a5',
#                       data_file = glue('{download_dir}{file_name}_years-{min(years_download)}-{max(years_download)}_{Sys.Date()}.zip')),
#     'parquet' = list(dataset_name = 'water-quality-effluent-electronic-self-monitoring-report-esmr-data',
#                      dataset_id = 'cce982b3-719f-4852-8979-923c3a639a25',
#                      data_file = glue('{download_dir}{file_name}_years-{min(years_download)}-{max(years_download)}_parquet_{Sys.Date()}.zip'))
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
    # id_number <- 2
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
        sleep_time <- 10 # seconds
        while(remDr$getCurrentUrl() == edit_url & i <= 120) { 
            print(glue('uploading (counter: {round(i * sleep_time / 60, 1)} minutes)'))
            Sys.sleep(sleep_time)
            i <- i + 1
        }
        t2 <- Sys.time()
        
        upload_time <- t2 - t1
        print(glue('upload complete -- upload time: {round(upload_time,1)} {units(upload_time)}'))  
    }
    
    # go to the next file
    
}



# close server ------------------------------------------------------------
remDr$close()
shell.exec(file = here('Stop.bat')) # this closes the java window
