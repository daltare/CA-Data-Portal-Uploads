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
## dataset names ----
dataset_name <- 'surface-water-toxicity-results'

## list files / resources ----
data_resource_id_list <- list('toxicity' = 'ac8bf4c8-0675-4764-92f1-b67bdb187ba1')



# set up selenium (automated browser) ---------------------------------
source(here('start_selenium.R'))

## Note - for more information / examples on how the RSelenium package works, see:
# https://stackoverflow.com/questions/35504731/specify-download-folder-in-rselenium        
# https://cran.r-project.org/web/packages/RSelenium/vignettes/RSelenium-basics.html
# https://stackoverflow.com/questions/32123248/submitting-form-from-r-to-mixed-html-and-javascript
# https://github.com/ropensci/RSelenium/issues/121


# ## define chrome browser options for the Selenium session ----
# eCaps <- list( 
#     chromeOptions = 
#         list(prefs = list(
#             "profile.default_content_settings.popups" = 0L,
#             "download.prompt_for_download" = FALSE,
#             "download.default_directory" = gsub(pattern = '/', replacement = '\\\\', x = getwd()) # download.dir
#         )
#         )
# )
# 
# ## check for open port ----
# for (port_check in 4567L:4577L) {
#     port_test <- ping_port(destination = 'localhost', port = port_check)
#     # print(all(is.na(port_test)))
#     if (all(is.na(port_test)) == TRUE) {
#         port_use <- port_check
#         break
#     }
# }
# 
# ## get drivers ----
# selenium(check = TRUE,
#          retcommand = TRUE,
#          port = port_use)
# Sys.sleep(1)
# 
# ## get current version of chrome browser ----
# chrome_browser_version <-
#     system2(command = "wmic",
#             args = 'datafile where name="C:\\\\Program Files (x86)\\\\Google\\\\Chrome\\\\Application\\\\chrome.exe" get Version /value',
#             stdout = TRUE,
#             stderr = TRUE) %>%
#     str_extract(pattern = "(?<=Version=)(\\d+\\.){3}")
# if (sum(!is.na(chrome_browser_version)) == 0) {
#     chrome_browser_version <-
#         system2(command = "wmic",
#                 args = 'datafile where name="C:\\\\Program Files\\\\Google\\\\Chrome\\\\Application\\\\chrome.exe" get Version /value',
#                 stdout = TRUE,
#                 stderr = TRUE) %>%
#         str_extract(pattern = "(?<=Version=)(\\d+\\.){3}")
# }
# 
# ## get available chrome drivers ----
# chrome_driver_versions <- list_versions("chromedriver")
# 
# ## match driver / version ----
# chrome_driver_current <- chrome_browser_version %>%
#     extract(!is.na(.)) %>%
#     str_replace_all(pattern = "\\.",
#                     replacement = "\\\\.") %>%
#     paste0("^",  .) %>%
#     str_subset(string = dplyr::last(chrome_driver_versions)) %>%
#     as.numeric_version() %>%
#     max() %>%
#     as.character()
# 
# ### if no matching driver / version, use most recent driver ----
# if(is_empty(chrome_driver_current)) {
#     chrome_driver_current <- tibble(version = last(chrome_driver_versions)) %>% 
#         separate_wider_delim(cols = version, 
#                              delim = '.', 
#                              names_sep = '', 
#                              cols_remove = FALSE) %>% 
#         rename(version = versionversion) %>% 
#         mutate(across(num_range('version', 1:4), as.numeric)) %>% 
#         arrange(desc(version1), desc(version2), desc(version3), desc(version4)) %>% 
#         slice(1) %>% 
#         pull(version)
# }
# 
# ## re-check for open port ----
# for (port_check in 4567L:4577L) {
#     port_test <- ping_port(destination = 'localhost', port = port_check)
#     # print(all(is.na(port_test)))
#     if (all(is.na(port_test)) == TRUE) {
#         port_use <- port_check
#         break
#     }
# }
# 
# #### remove the 'LICENSE.chromedriver' file (if it exists)
# chrome_driver_dir <- paste0(app_dir("chromedriver", FALSE), 
#                             '/win32/',
#                             chrome_driver_current)
# # list.files(chrome_driver_dir)
# if ('LICENSE.chromedriver' %in% list.files(chrome_driver_dir)) {
#     file.remove(
#         paste0(chrome_driver_dir, '/', 'LICENSE.chromedriver')
#     )
# }
# 
# ## set up selenium with the current chrome version ----
# selCommand <- selenium(jvmargs = 
#                            c("-Dwebdriver.chrome.verboseLogging=true"), 
#                        check = TRUE,
#                        retcommand = TRUE,
#                        chromever = chrome_driver_current,
#                        port = port_use)
# 
# ## write selenium specifications to batch file ----
# writeLines(selCommand, 
#            'Start_Server.bat')
# Sys.sleep(1) #### wait a few seconds
# 
# ## start server ----
# shell.exec('Start_Server.bat')
# Sys.sleep(1) #### wait a few seconds
# 
# ## open connection ----
# remDr <- remoteDriver(port = port_use, # 4567L, 
#                       browserName = "chrome", 
#                       extraCapabilities = eCaps)
# Sys.sleep(1) #### wait a few seconds
# remDr$open()




# load files to portal -----------------------------------------
## get portal username and password ----
portal_username <- Sys.getenv('portal_username') 
portal_password <- Sys.getenv('portal_password')

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
for (id_number in seq_along(names(data_resource_id_list))) {
    # id_number <- 1
    data_resource_id <- data_resource_id_list[[id_number]]
    
    ### navigate to resource editor page ----
    edit_url <- paste0('https://data.ca.gov/dataset/', dataset_name, '/resource_edit/', data_resource_id)
    remDr$navigate(edit_url)
    
    # click the 'Remove' button (to remove the old version of the file)
    webElem <- remDr$findElement(using = 'css selector', value = paste0('.btn-remove-url'))
    webElem$clickElement()
    Sys.sleep(1)
    
    # enter the path of the new file to be uploaded
    webElem <- remDr$findElement(using = 'css selector', value = paste0('#field-image-upload'))
    # webElem$clickElement()
    webElem$sendKeysToElement(list('C:\\David\\_CA_data_portal\\CEDEN\\CEDEN_Datasets\\2021-09-01\\ToxicityData_2021-09-01.zip'))
    Sys.sleep(1)
    
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
