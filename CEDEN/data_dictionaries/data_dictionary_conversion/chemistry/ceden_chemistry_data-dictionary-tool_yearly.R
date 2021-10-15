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
    bat_file_location <- 'C:\\David\\Stormwater\\_SMARTS_Data_Download_Automation\\'
    
# load packages
    library(RSelenium)
    library(methods) # it seems that this needs to be called explicitly to avoid an error for some reason
    library(XML)
    library(dplyr)
    library(janitor)
    library(readr)
    library(lubridate)
    library(readxl)
    library(ckanr)

# Enter variables:
    # User Input
    # dictionary_filename <- readline(prompt="Enter the filename of the data dictionary to upload: ")
    # dictionary_fields <- c('column', 'type', 'label', 'description') # has to be in order: Column, Type, Label, Description
    # dataset_name <- readline(prompt="Enter the name of the dataset on the open data portal: ")
    # data_resource_id <- readline(prompt="Enter the ID of the resource on the open data portal (from the resource's URL): ")
    
    # Chemistry - all years
    dictionary_filename <- 'CEDEN_Chemistry_Data_Dictionary.xlsx'
    dictionary_fields <- c('column', 'type', 'label', 'description') # has to be in order: Column, Type, Label, Description
    dataset_name <- 'surface-water-chemistry-results'
    
    # get the resource IDs
    package_id <- '28d7a81d-6458-47bd-9b79-4fcbfbb88671' # chemistry
    dataset_resources <- package_show(package_id, as = 'table', url = "https://data.ca.gov/", key = Sys.getenv('data_portal_key'))
    dataset_resources <- dataset_resources$resources %>% 
        filter(format %in% c('CSV')) %>% # filter for just the resources containing csv files
        select(name, id)
    
    data_resource_id_list <-  list(#'2021' = 'dde19a95-504b-48d7-8f3e-8af3d484009f',
                                   # '2020' = '2eba14fa-2678-4d54-ad8b-f60784c1b234', 
                                   # '2019' = '6cf99106-f45f-4c17-80af-b91603f391d9',
                                   # '2018' = 'f638c764-89d5-4756-ac17-f6b20555d694',
                                   # '2017' = '68787549-8a78-4eea-b5b9-ef719e65a05c', 
                                   # '2016' = '42b906a2-9e30-4e44-92c9-0f94561e47fe', 
                                   # '2015' = '7d9384fa-70e1-4986-81d6-438ce5565be6',
                                   # '2014' = '7abfde16-61b6-425d-9c57-d6bd70700603', 
                                   # '2013' = '341627e6-a483-4e9e-9a85-9f73b6ddbbba',
                                   # '2012' = 'f9dd0348-85d5-4945-aa62-c7c9ad4cf6fd', 
                                   # '2011' = '4d01a693-2a22-466a-a60b-3d6f236326ff', 
                                   # '2010' = '572bf4d2-e83d-490a-9aa5-c1d574e36ae0', 
                                   # '2009' = '5b136831-8870-46f2-8f72-fe79c23d7118',
                                   # '2008' = 'c587a47f-ac28-4f77-b85e-837939276a28',
                                   # '2007' = '13e64899-df32-461c-bec1-a4e72fcbbcfa',
                                   # '2006' = 'a31a7864-06b9-4a81-92ba-d8912834ca1d',
                                   # '2005' = '9538cbfa-f8be-4445-97dc-b931579bb927', 
                                   # '2004' = 'c962f46d-6a7b-4618-90ec-3c8522836f28',
                                   # '2003' = 'd3f59df4-2a8d-4b40-b90f-8147e73335d9',
                                   # '2002' = '00c4ca34-064f-4526-8276-57533a1a36d9',
                                   # '2001' = 'cec6768c-99d3-45bf-9e56-d62561e9939e',
                                   '2000' = '99402c9c-5175-47ca-8fce-cb6c5ecc8be6',
                                   'prior_to_2000' = '158c8ca1-b02f-4665-99d6-2c1c15b6de5a'
                                   )

        

# STEP 1: Get the dictionary info ----
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
        # NEW METHOD (works when running as an automated task)
            # Run this, and paste the output into a terminal (cmd) window
                # selCommand <- wdman::selenium(jvmargs = c("-Dwebdriver.chrome.verboseLogging=true"), retcommand = TRUE)
                # cat(selCommand)
                # This command starts the server, by entering the output from the line above into a command window
                    shell.exec(file = paste0(bat_file_location , 'Start_Server.bat'))
            # NOTE: There can be a mismatch between the Chrome browser version and the Chrome driver version - if so, it may 
                # be necessary to manually edit the output of the steps above to point to the correct version of the 
                # driver (at: C:\Users\daltare\AppData\Local\binman\binman_chromedriver\win32) - also see: https://stackoverflow.com/questions/55201226/session-not-created-this-version-of-chromedriver-only-supports-chrome-version-7
            # open the connection
                remDr <- RSelenium::remoteDriver(port = 4567L, browserName = "chrome", extraCapabilities = eCaps)
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
    shell.exec(file = paste0(bat_file_location, 'Stop.bat')) # this closes the java window
