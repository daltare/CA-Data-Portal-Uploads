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

# Enter variables:
    # User Input
    # dictionary_filename <- readline(prompt="Enter the filename of the data dictionary to upload: ")
    # dictionary_fields <- c('column', 'type', 'label', 'description') # has to be in order: Column, Type, Label, Description
    # dataset_name <- readline(prompt="Enter the name of the dataset on the open data portal: ")
    # data_resource_id <- readline(prompt="Enter the ID of the resource on the open data portal (from the resource's URL): ")
    
    # Chemistry: prior to 2000
    dictionary_filename <- 'CEDEN_Chemistry_Data_Dictionary.xlsx'
    dictionary_fields <- c('column', 'type', 'label', 'description') # has to be in order: Column, Type, Label, Description
    dataset_name <- 'surface-water-chemistry-results'
    data_resource_id <- '6cf99106-f45f-4c17-80af-b91603f391d9'
    
    # # Chemistry: 2000 - 2009
    # dictionary_filename <- 'CEDEN_Chemistry_Data_Dictionary.xlsx'
    # dictionary_fields <- c('column', 'type', 'label', 'description') # has to be in order: Column, Type, Label, Description
    # dataset_name <- 'surface-water-chemistry-results'
    # data_resource_id <- 'feb79718-52b6-4aed-8f02-1493e6187294'
    
    # # Chemistry: 2010 - Present
    # dictionary_filename <- 'CEDEN_Chemistry_Data_Dictionary.xlsx'
    # dictionary_fields <- c('column', 'type', 'label', 'description') # has to be in order: Column, Type, Label, Description
    # dataset_name <- 'surface-water-chemistry-results'
    # data_resource_id <- 'afaeb2b2-e26f-4d18-8d8d-6aade151b34a'
    
# load packages
    library(RSelenium)
    library(methods) # it seems that this needs to be called explicitly to avoid an error for some reason
    library(XML)
    library(dplyr)
    library(janitor)
    library(readr)
    library(lubridate)
    library(readxl)
        

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


# close the server
    remDr$close()
    # rsD$server$stop() # from the old method
    rm(list = c('remDr'))#'eCaps', , 'SMARTS_url', 'rsD'))
    gc()   
    shell.exec(file = paste0(bat_file_location, 'Stop.bat')) # this closes the java window
