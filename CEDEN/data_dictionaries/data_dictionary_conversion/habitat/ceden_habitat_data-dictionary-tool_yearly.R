# Notes:
    # 1. The dictionary file should be an excel file with the header names 'column', 'label', 'type', and eithter 'description' or 'description_combined' (it may also have other colums as well - doesn't matter)
    # 2. The order of the fields listed in the dictionary MUST match the order of the columns in the dataset
    # 3. Make sure the fields defined as numeric or timestamp in the dictionary are correctly formatted in the dataset (missing numeric values must be 'NaN', dates must be in ISO format and missing dates should be an empty text string i.e. '')
    # 4. Put the dictionary file in the same location as this script file
    # 5. Enter your data.ca.gov portal username in the environment variables for you account, in a variable called 'portal_username'
    # 6. Enter your data.ca.gov portal password in the environment variables for you account, in a variable called 'portal_password'
    # 7. Note that the 'type' field doesn't update until the datastore is updated (go to 'Manage', 'Data Store', click 'Upload to DataStore')


# NOTE: if this stops working with an error message related to the Chrome WebDriver, take the following steps:
    # 1. Check the version of Chrome currently installed
    # 2. Go to the following website and download/save the corresponding version of the Chrome WebDriver: https://sites.google.com/a/chromium.org/chromedriver/downloads
    # 3. Unzip the folder, and rename the unzipped folder with the version of the WebDriver
    # 4. Copy that folder to the following location: C:\Users\daltare\AppData\Local\binman\binman_chromedriver\win32 (there should be old versions of the driver there too)
    # 5. Go to the 'Start_Server.bat' file, right click on it and open with a text editor, then find the part relating to the Chrome driver and change the version number (i.e. folder name) to the version you just downloaded - e.g. in this part, change the "77.0.3865.40" to the new version:
            # -Dwebdriver.chrome.driver="C:\Users\daltare\AppData\Local\binman\binman_chromedriver\win32\77.0.3865.40/chromedriver.exe"
                    
# Enter Location of "Start_Server.bat" and "Stop.bat" files
    library(here)
    bat_file_location <- here()
    
# load packages
    library(tidyverse)
    library(RSelenium)
    library(wdman)
    library(methods) # it seems that this needs to be called explicitly to avoid an error for some reason
    library(XML)
    library(dplyr)
    library(janitor)
    library(readr)
    library(lubridate)
    library(readxl)
    library(ckanr)
    library(pingr)
    library(binman)

# Enter variables:
    # User Input
    # dictionary_filename <- readline(prompt="Enter the filename of the data dictionary to upload: ")
    # dictionary_fields <- c('column', 'type', 'label', 'description') # has to be in order: Column, Type, Label, Description
    # dataset_name <- readline(prompt="Enter the name of the dataset on the open data portal: ")
    # data_resource_id <- readline(prompt="Enter the ID of the resource on the open data portal (from the resource's URL): ")

    
    # Habitat: Yearly
    dictionary_filename <- 'CEDEN_Habitat_Data_Dictionary.xlsx'
    dictionary_fields <- c('column', 'type', 'label', 'description') # has to be in order: Column, Type, Label, Description
    dataset_name <- 'surface-water-habitat-results'
    
    # get the resource IDs
    package_id <- 'f5edfd1b-a9b3-48eb-a33e-9c246ab85adf' # habitat
    dataset_resources <- package_show(package_id, as = 'table', url = "https://data.ca.gov/", key = Sys.getenv('data_portal_key'))
    dataset_resources <- dataset_resources$resources %>% 
        filter(format %in% c('CSV')) %>% # filter for just the resources containing csv files
        select(name, id)
    data_resource_id_list <-  list(#'Pre-2000' = 'a3dcc442-e722-495f-ad59-c704ae934848',
                                   # '2000' = 'b3dba1ee-6ada-42d5-9679-1a10b44630bc',
                                   # '2001' = 'ea8b0171-e226-4e80-991d-50752abea734',
                                   # '2002' = 'a9d8302d-0d37-4cf3-bbeb-386f6bd948a6',
                                   # '2003' = '899f3ebc-538b-428e-8f1f-d591445a847c',
                                   # '2004' = 'e5132397-69a5-46fb-b24a-cd3b7a1fe53a',
                                   # '2005' = '1609e7ab-d913-4d24-a582-9ca7e8e82233',
                                   # '2006' = '88b33d5b-5428-41e2-b77b-6cb46ca5d1e4',
                                   # '2007' = '1659a2b4-21e5-4fc4-a9a4-a614f0321c05',
                                   # '2008' = 'ce211c51-05a2-4a7c-be18-298099a0dcd2',
                                   # '2009' = 'd025552d-de5c-4f8a-b2b5-a9de9e9c86c3',
                                   # '2010' = '2a8b956c-38fa-4a15-aaf9-cb0fcaf915f3',
                                   # '2011' = '2fa6d874-1d29-478a-a5dc-0c2d31230705',
                                   # '2012' = '78d44ee3-65af-4c83-b75e-8a82b8a1db88',
                                   # '2013' = '3be276c3-9966-48de-b53a-9a98d9006cdb',
                                   # '2014' = '082a7665-8f54-4e4f-9d24-cc3506bb8f3e',
                                   # '2015' = '115c55e3-40af-4734-877f-e197fdae6737',
                                   # '2016' = '01e35239-6936-4699-b9db-fda4751be6e9',
                                   # '2017' = 'f7a33584-510f-46f8-a314-625f744ecbdd',
                                   # '2018' = 'd814ca0c-ace1-4cc1-a80f-d63f138e2f61',
                                   # '2019' = 'c0f230c5-3f51-4a7a-a3db-5eb8692654aa',
                                   # '2020' = 'bd37df2e-e6a4-4c2b-b01c-ce7840cc03de', 
                                   '2021' = 'c82a3e83-a99b-49d8-873b-a39640b063fc', 
                                   '2022' = '0fcdfad7-6588-41fc-9040-282bac2147bf')
        

# STEP 1: Get the dictionary info ----
    # get the info to fill out the data dictionary 
        df_dictionary <- read_excel(here('data_dictionaries', 'data_dictionary_conversion', 'habitat', 
                                         dictionary_filename)) %>% 
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

    
    
# STEP 2: Set up the methodology to automate data entry, using RSelenium (use the Chrome browser in this script) ----
    # Note - for more information / examples on how the RSelenium package works, see:
        # https://stackoverflow.com/questions/35504731/specify-download-folder-in-rselenium        
        # https://cran.r-project.org/web/packages/RSelenium/vignettes/RSelenium-basics.html
        # https://stackoverflow.com/questions/32123248/submitting-form-from-r-to-mixed-html-and-javascript
        # https://github.com/ropensci/RSelenium/issues/121


    # Set up RSelenium 
    # define the chrome browser options for the Selenium session
        eCaps <- list( 
            chromeOptions = 
                list(prefs = list(
                    "profile.default_content_settings.popups" = 0L,
                    "download.prompt_for_download" = FALSE,
                    "download.default_directory" = gsub(pattern = '/', replacement = '\\\\', x = getwd()) # download.dir
                )
                )
        )

    # Open the connection
        # OLD METHOD (for some reason it doesn't work when running as an automated task with the task scheduler, but does work when just running from a normal RStudio session) 
            # rsD <- RSelenium::rsDriver(port = 4444L, browser = 'chrome', extraCapabilities = eCaps) #, chromever = "75.0.3770.90")
            # remDr <- rsD$client
            # probably don't need these lines anymore:
            # remDr <- remoteDriver(browserName="chrome", port = 4444L, extraCapabilities = eCaps)
            # remDr$open()
    
    #### NEW METHOD (works when running as an automated task)
    #### (see: https://github.com/ropensci/RSelenium/issues/221)
    
    # selenium(jvmargs = 
    #              c("-Dwebdriver.chrome.verboseLogging=true"), 
    #          retcommand = TRUE)
    
    
    #### check for open port ----
    for (port_check in 4567L:4577L) {
        port_test <- ping_port(destination = 'localhost', port = port_check)
        # print(all(is.na(port_test)))
        if (all(is.na(port_test)) == TRUE) {
            port_use <- port_check
            break
        }
    }
    
    #### get drivers ----
    selenium(jvmargs = 
                 c("-Dwebdriver.chrome.verboseLogging=true"), 
             retcommand = TRUE,
             port = port_use)
    Sys.sleep(5)
    
    #### get current version of chrome browser ----
    chrome_browser_version <-
        system2(command = "wmic",
                args = 'datafile where name="C:\\\\Program Files (x86)\\\\Google\\\\Chrome\\\\Application\\\\chrome.exe" get Version /value',
                stdout = TRUE,
                stderr = TRUE) %>%
        str_extract(pattern = "(?<=Version=)(\\d+\\.){3}")
    if (sum(!is.na(chrome_browser_version)) == 0) {
        chrome_browser_version <-
            system2(command = "wmic",
                    args = 'datafile where name="C:\\\\Program Files\\\\Google\\\\Chrome\\\\Application\\\\chrome.exe" get Version /value',
                    stdout = TRUE,
                    stderr = TRUE) %>%
            str_extract(pattern = "(?<=Version=)(\\d+\\.){3}")
    }
    
    #### get available chrome drivers ----
    chrome_driver_versions <- list_versions("chromedriver")
    
    #### match driver / version ----
    chrome_driver_current <- chrome_browser_version %>%
        magrittr::extract(!is.na(.)) %>%
        str_replace_all(pattern = "\\.",
                        replacement = "\\\\.") %>%
        paste0("^",  .) %>%
        str_subset(string = last(chrome_driver_versions)) %>%
        as.numeric_version() %>%
        max() %>%
        as.character()
    
    #### re-check for open port ----
    for (port_check in 4567L:4577L) {
        port_test <- ping_port(destination = 'localhost', port = port_check)
        # print(all(is.na(port_test)))
        if (all(is.na(port_test)) == TRUE) {
            port_use <- port_check
            break
        }
    }
    
    #### set up selenium with the current chrome version ----
    selCommand <- selenium(jvmargs = 
                               c("-Dwebdriver.chrome.verboseLogging=true"), 
                           retcommand = TRUE,
                           chromever = chrome_driver_current,
                           port = port_use)
    
    #### OLD - No longer needed
    # cat(selCommand) # view / print to console #Run this, and paste the output into a terminal (cmd) window
    
    #### write selenium specifications to batch file ----
    writeLines(selCommand, 
               paste0(bat_file_location, '/Start_Server.bat'))
    Sys.sleep(5) #### wait a few seconds
    
    #### start server ----
    shell.exec(here('Start_Server.bat'))
    
    Sys.sleep(10) #### wait a few seconds
    
    # This command starts the server, by entering the output from the line above into a command window
    # shell.exec(file = 'C:/David/Stormwater/_SMARTS_Data_Download_Automation/Start_Server.bat')
    # NOTE: There can be a mismatch between the Chrome browser version and the Chrome driver version - if so, it may 
    # be necessary to manually edit the output of the steps above to point to the correct version of the 
    # driver (at: C:\Users\daltare\AppData\Local\binman\binman_chromedriver\win32) - also see: https://stackoverflow.com/questions/55201226/session-not-created-this-version-of-chromedriver-only-supports-chrome-version-7
    
    ### open connection ----
    remDr <- remoteDriver(port = port_use, # 4567L, 
                          browserName = "chrome", 
                          extraCapabilities = eCaps)
    Sys.sleep(10) #### wait a few seconds
    remDr$open()  

# STEP 3: Enter the data ----
    # get portal username and password
        portal_username <- Sys.getenv('portal_username') 
        portal_password <- Sys.getenv('portal_password')

    # Navigate to the data.ca.gov login page and log in
        login_url <- 'https://data.ca.gov/user/login'
        remDr$navigate(login_url)
        webElem <- remDr$findElement(using = 'id', value = 'field-login')
        webElem$sendKeysToElement(list(portal_username))
        webElem <- remDr$findElement(using = 'id', value = 'field-password')
        webElem$sendKeysToElement(list(portal_password))
        webElem <- remDr$findElement(using = 'css selector', value = 'button.btn.btn-primary')
        webElem$clickElement()
        
    # loop through the resources
        for (id_number in seq_along(names(data_resource_id_list))) {
            data_resource_id <- data_resource_id_list[[id_number]]
            
            # Navigate to the data dictionary editor page
            dictionary_url <- paste0('https://data.ca.gov/dataset/', dataset_name, '/dictionary/', data_resource_id)
            remDr$navigate(dictionary_url)
            
            # loop through all of the fields defined in the dictionary and enter into the data dictionary interface on the portal
            for (i in seq(nrow(df_dictionary))){
                # enter the field type
                webElem <- remDr$findElement(using = 'id', value = paste0('info__', i, '__type_override'))
                webElem$sendKeysToElement(list(df_dictionary[[i, dictionary_fields[2]]]))
                # enter the label
                webElem <- remDr$findElement(using = 'id', value = paste0('field-f', i, 'label'))
                webElem$clearElement()
                webElem$sendKeysToElement(list(df_dictionary[[i, dictionary_fields[3]]]))
                # enter the description
                webElem <- remDr$findElement(using = 'id', value = paste0('field-d', i, 'notes'))
                webElem$clearElement()
                webElem$sendKeysToElement(list(df_dictionary[[i, dictionary_fields[4]]]))
            }
            
            # click the save button
            webElem <- remDr$findElement(using = 'css selector', value = 'button.btn.btn-primary')
            webElem$clickElement()
        }


# close the server
    remDr$close()
    # rsD$server$stop() # from the old method
    rm(list = c('remDr'))#'eCaps', , 'SMARTS_url', 'rsD'))
    gc()   
    shell.exec(file = paste0(bat_file_location, '/Stop.bat')) # this closes the java window
