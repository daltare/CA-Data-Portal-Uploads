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
    
    # Tissue: all years
    dictionary_filename <- 'CEDEN_Tissue_Data_Dictionary.xlsx'
    dictionary_fields <- c('column', 'type', 'label', 'description') # has to be in order: Column, Type, Label, Description
    dataset_name <- 'surface-water-aquatic-organism-tissue-sample-results'
    
    # get the resource IDs
    package_id <- '38cb5cca-1500-42e7-b359-e8e3c5d1e087' # tissue
    dataset_resources <- package_show(package_id, as = 'table', url = "https://data.ca.gov/", key = Sys.getenv('data_portal_key'))
    dataset_resources <- dataset_resources$resources %>% 
        filter(format %in% c('CSV')) %>% # filter for just the resources containing csv files
        select(name, id)
    
    data_resource_id_list <-  list(# 'Pre-2000' = '97786a54-1189-43e4-9244-5dcb241dfa58',
                                   # '2000' = '06b35b3c-6338-44cb-b465-ba4c1863b7c5',
                                   # '2001' = '47df34fd-8712-4f72-89ff-091b3e954399',
                                   # '2002' = '6a56b123-9275-4549-a625-e5aa6f2b8b57',
                                   # '2003' = '1a21e2ac-a9d8-4e81-a6ad-aa6636d064d1',
                                   # '2004' = '1dc7ed28-a59b-48a7-bc81-ef9582a4efaa',
                                   # '2005' = '77daaca9-3f47-4c88-9d22-daf9f79e2729',
                                   # '2006' = 'f3ac3204-f0a2-4561-ae18-836b8aafebe8',
                                   # '2007' = 'f88461cf-49b2-4c5c-ba2c-d9484202bc74',
                                   # '2008' = 'da39833c-9d62-4307-a93e-2ae8ad2092e3',
                                   # '2009' = 'c1357d10-41cb-4d84-bd3a-34e18fa9ecdf',
                                   # '2010' = '82dbd8ec-4d59-48b5-8e10-ce1e41bbf62a',
                                   # '2011' = '06440749-3ada-4461-959f-7ac2699faeb0',
                                   # '2012' = '8e3bbc50-dd72-4cee-b926-b00f488ff10c',
                                   # '2013' = 'eb2d102a-ecdc-4cbe-acb9-c11161ac74b6',
                                   # '2014' = '8256f15c-8500-47c3-be34-d12b45b0bbe9',
                                   # '2015' = '3376163c-dcda-4b76-9672-4ecfee1e1417',
                                   # '2016' = 'c7a56123-8692-4d92-93cc-aa12d7ab46c9',
                                   # '2017' = 'e30e6266-5978-47f4-ae6a-94336ab224f9',
                                   # '2018' = '559c5523-8883-4da0-9750-f7fd3f088cfb',
                                   # '2019' = 'edd16b08-3d9f-4375-9396-dce7cbd2f717',
                                   # '2020' = 'a3545e8e-2ab5-46b3-86d5-72a74fcd8261',
                                   '2021' = '02e2e832-fa46-4ecb-98e8-cdb70fe3902d')

# STEP 1: Get the dictionary info ----
    # get the info to fill out the data dictionary 
        df_dictionary <- read_excel(here('data_dictionaries', 'data_dictionary_conversion', 'tissue', 
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
