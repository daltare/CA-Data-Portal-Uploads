# NOTE: if this stops working with an error message related to the Chrome WebDriver, take the following steps:
# 1. Check the version of Chrome currently installed
# 2. Go to the following website and download/save the corresponding version of the Chrome WebDriver: https://sites.google.com/a/chromium.org/chromedriver/downloads
# 3. Unzip the folder, and rename the unzipped folder with the version of the WebDriver
# 4. Copy that folder to the following location: C:\Users\daltare\AppData\Local\binman\binman_chromedriver\win32 (there should be old versions of the driver there too)
# 5. Go to the 'Start_Server.bat' file, right click on it and open with a text editor, then find the part relating to the Chrome driver and change the version number (i.e. folder name) to the version you just downloaded - e.g. in this part, change the "77.0.3865.40" to the new version:
# -Dwebdriver.chrome.driver="C:\Users\daltare\AppData\Local\binman\binman_chromedriver\win32\77.0.3865.40/chromedriver.exe"


# NOTE: To schedule this script to run automatically, go to 'Addins' and 'Schedule R scripts on...', then select 
# the file that calls this script ("C:\\David\\Open_Data_Project\\__CA_DataPortal\\_Call_Scripts\\_Call_SMARTS_download.R")
# and set the time/date option (make sure the date format is %m/%d/%Y)


# STEP 1: Set up the methodology to automate data download from the SMARTS interface, using RSelenium (use the Chrome browser in this script) ----

# load packages -----------------------------------------------------------
library(RSelenium)
library(wdman)
library(methods) # it seems that this needs to be called explicitly to avoid an error for some reason
library(XML)
library(dplyr)
library(janitor)
library(readr)
library(lubridate)
library(glue)
library(sendmailR)
library(blastula)
library(binman)
library(stringr)
library(magrittr)
library(pingr)
library(ckanr)




# 1 - user input --------------------------------------------------------------
## set download directory ----
##(i.e., where to save any downloaded files)
download_dir <- 'C:\\David\\_CA_data_portal\\SMARTS'

## delete old files
delete_old_versions = TRUE # whether or not to delete previous versions of each dataset - FALSE means to keep the old versions
# NOTE: currently set to keep the versions from the previous 7 days if TRUE

## enter the email address to send warning emails from
### NOTE - if sending from a personal email address, you'll have to update the credentials -- see below
email_from <- 'david.altare@waterboards.ca.gov' # "gisscripts-noreply@waterboards.ca.gov"

## enter the email address (or addresses) to send warning emails to
email_to <- 'david.altare@waterboards.ca.gov' # c('david.altare@waterboards.ca.gov', 'waterdata@waterboards.ca.gov')

## get data portal API key (saved in the local environment)
### (it's available on data.ca.gov by going to your user profile)
portal_key <- Sys.getenv('data_portal_key')


# 2 - setup automated email -----------------------------------------------
## create credentials file (only need to do this once) ----
# create_smtp_creds_file(file = 'outlook_creds', 
#                        user = 'david.altare@waterboards.ca.gov',
#                        provider = 'outlook'
#                        )   

## create email function ----
fn_send_email <- function(error_msg, error_msg_r) {
    
    ### create components ----
    #### date/time ----
    date_time <- add_readable_time()
    
    #### body ----
    body <- glue(
        "Hi,
        
There was an error uploading the SMARTS (stormwater) data to the data.ca.gov portal on {Sys.Date()}.

------
                
The process failed at this step: *{error_msg}*

Here's the error message from R: *{error_msg_r}*

------
                
Here's the link to the dataset on the data portal: https://data.ca.gov/dataset/stormwater-regulatory-including-enforcement-actions-information-and-water-quality-results
                
Here's the link to the source data: https://smarts.waterboards.ca.gov/smarts/faces/SwSmartsLogin.xhtml"                
    )
    
    #### footer ----
    footer <- glue("Email sent on {date_time}.")
    
    #### subject ----
    subject <- "Data Portal Upload Error - SMARTS (Stormwater) Data"
    
    ### create email ----
    email <- compose_email(
        body = md(body),
        footer = md(footer)
    )
    
    
    ### send email via blastula (using credentials file) ----
    email %>%
        smtp_send(
            to = email_to,
            from = email_from,
            subject = subject,
            credentials = creds_file("outlook_creds")
            # credentials = creds_key("outlook_key")
        )
    
    ### send email via sendmailR (for use on GIS scripting server) ----
    # from <- email_from
    # to <- email_to
    # sendmail(from,to,subject,body,control=list(smtpServer= "gwgate.waterboards.ca.gov"))
    
    print('sent automated email')
}


# 3 - source additional scripts -----------------------------------------------
tryCatch(
    source('1_FilesList.R'), # get information about the files to be retrieved from the SMARTS interface
    error = function(e) {
        error_message <- 'sourcing extra scripts'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

# 4 - Setup RSelenium --------------------------------------------------------
# Note - for more information / examples on how the RSelenium package works, see:
# https://stackoverflow.com/questions/35504731/specify-download-folder-in-rselenium        
# https://cran.r-project.org/web/packages/RSelenium/vignettes/RSelenium-basics.html
# https://stackoverflow.com/questions/32123248/submitting-form-from-r-to-mixed-html-and-javascript
# https://github.com/ropensci/RSelenium/issues/121

tryCatch(
    {
        ## define chrome browser options for the Selenium session ----
        eCaps <- list( 
            chromeOptions = 
                list(prefs = list(
                    "profile.default_content_settings.popups" = 0L,
                    "download.prompt_for_download" = FALSE,
                    "download.default_directory" = gsub(pattern = '/', replacement = '\\\\', x = download_dir) # "download.default_directory" = gsub(pattern = '/', replacement = '\\\\', x = getwd())
                )
                )
        )
        
        ## Open the connection ----
        ### setup ----
        #### OLD METHOD (for some reason it doesn't work when running as an automated task with the task scheduler, but does work when just running from a normal RStudio session) 
        # rsD <- rsDriver(port = 4444L, browser = 'chrome', extraCapabilities = eCaps) #, chromever = "75.0.3770.90")
        # remDr <- rsD$client
        # probably don't need these lines anymore:
        # remDr <- remoteDriver(browserName="chrome", port = 4444L, extraCapabilities = eCaps)
        # remDr$open()
        
        
        #### NEW METHOD (works when running as an automated task)
        #### (see: https://github.com/ropensci/RSelenium/issues/221)
        
        # selenium(jvmargs = 
        #              c("-Dwebdriver.chrome.verboseLogging=true"), 
        #          retcommand = TRUE)
        
        #### get current version of chrome browser ----
        chrome_browser_version <-
            system2(command = "wmic",
                    args = 'datafile where name="C:\\\\Program Files (x86)\\\\Google\\\\Chrome\\\\Application\\\\chrome.exe" get Version /value',
                    stdout = TRUE,
                    stderr = TRUE) %>%
            str_extract(pattern = "(?<=Version=)(\\d+\\.){3}")
        
        #### get available chrome drivers ----
        chrome_driver_versions <- list_versions("chromedriver")
        
        #### match driver / version ----
        chrome_driver_current <- chrome_browser_version %>%
            extract(!is.na(.)) %>%
            str_replace_all(pattern = "\\.",
                                     replacement = "\\\\.") %>%
            paste0("^",  .) %>%
            str_subset(string = last(chrome_driver_versions)) %>%
            as.numeric_version() %>%
            max() %>%
            as.character()
        
        #### check for open port
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
                   'Start_Server.bat')
        Sys.sleep(5) #### wait a few seconds
        
        #### start server ----
        shell.exec('Start_Server.bat')
        
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
        
    },
    ## Error function
    error = function(e) {
        error_message <- 'setting up and connecting to Selenium'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        # remDr$close()
        shell.exec(file = 'Stop.bat')
        stop(e)
    }
)



# 5 - navigate to data & download ---------------------------------------------

tryCatch(
    {
        ## Define an amount of time to wait for pages to load
        # remDr$setImplicitWaitTimeout(milliseconds = 10000)
        
        ## Navigate to SMARTS homepage ----
        SMARTS_url <- "https://smarts.waterboards.ca.gov/smarts/SwPublicUserMenu.xhtml"
        remDr$navigate(SMARTS_url)
        homeWindow <- remDr$getCurrentWindowHandle()
        
        # # define a function to convert dates and times into a timestamp field that can be read by the portal - ADDED 2019-09-18
        #     convert_to_timestamps <- function(dataset_input, date_field, time_field, timestamp_name) {
        #         # Get a list of the date fields in the ISO format
        #             dates_iso <- mdy(dataset_input[[date_field]])
        #         # Create a vector of timestamps for any date (plus associated time) fields in the dataset
        #             timestamps <- mdy_hm(paste(dataset_input[[date_field]], dataset_input[[time_field]]))
        #             # check NAs: sum(is.na(timestamps))
        #         # For timestamps that don't work, just use the date (times are often not in a standard format)
        #             timestamps[is.na(timestamps)] <- dates_iso[is.na(timestamps)]
        #             # check NAs: sum(is.na(timestamps))
        #         # Convert to text, and for timestamps that still don't work, store as '' (empty text string) - this converts to 'null' in Postgres
        #             timestamps <- as.character(timestamps)
        #             timestamps[is.na(timestamps)] <- ''
        #             # check NAs: sum(is.na(timestamps))
        #         # Insert the timestamp fields into the dataset
        #             dataset_input[,timestamp_name] <- timestamps
        #     }
        
        ## navigate to the location of the relevant data in SMARTS ----
        
        ### open link to the "Download NOI Data By Regional Board" page ----
        webElem <- remDr$findElement(using = 'id', value = 'publicMenuForm:noiDataLink')
        webElem$clickElement()
        allWins <- unlist(remDr$getWindowHandles())
        noiWindow <- allWins[!allWins %in% homeWindow[[1]]]
        
        ### Switch to the "Download NOI Data..." page ----
        # remDr$switchToWindow(noiWindow) # this no longer works... need to use the custom function below, from: https://github.com/ropensci/RSelenium/issues/143
        myswitch <- function (remDr, windowId) 
        {
            qpath <- sprintf("%s/session/%s/window", remDr$serverURL, 
                             remDr$sessionInfo[["id"]])
            remDr$queryRD(qpath, "POST", qdata = list(handle = windowId))
        }
        myswitch(remDr = remDr, windowId = noiWindow[[1]])
        
        ### find and select the 'Select Regional Board' dropdown box ----
        webElem <- remDr$findElement(using = 'id', value = 'intDataFileDowloaddataFileForm:intDataDumpSelectOne')
        
        ### Set the dropdown value to 'State Board'
        webElem$sendKeysToElement(list('State Board', key = 'enter'))
        # NOTE: It's also possible to do this 'manually' (i.e., by recreating the mouse actions and button clicks), like this:
        # loc <- webElem$getElementLocation()
        # remDr$mouseMoveToLocation(webElement = webElem)
        # remDr$click()
        # # create a list with the actions (down arrow, enter, etc.)
        #     select_board_dropdown <- list()
        #     for (i in 1:13) {
        #         select_board_dropdown[i] = c('key' = 'down_arrow')
        #     }
        #     select_board_dropdown[i+1] = c('key' = 'enter')
        # remDr$sendKeysToActiveElement(
        #     select_board_dropdown
        # ) 
    },
    ## Error function
    error = function(e) {
        error_message <- 'navigating to data download page'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        remDr$close()
        shell.exec(file = 'Stop.bat')
        stop(e)
    }
)


### create function to download text file data from SMARTS ----
#### use to loop through all of the datasets defined at the top of the script in the 'dataset_list' variable
#### function downloads a given dataset from the "Download NOI Data By Regional Board" page
SMARTS_data_download <- function(filename, html_id, delete_old_versions = FALSE, fields_dates, fields_times, fields_timestamps, fields_numeric) { # NOTE: The html_id is the identifier of the button/link for the given dataset in the html code (use the 'developer' too in the browser to find this in the html code)
    # this automatically downloads the file to the default download location for the browser, set above
    # NOTE: Files downloaed from SMARTS are automatically named file.txt, so check to make sure there isn't already an un-named file (file.txt) in 
    # this location  - if so, delete it (otherwise the newly downloaded file will be appended with a number, and the versions might get confused)
    if (file.exists(paste0(download_dir, '\\', 'file.txt'))) {
        unlink(paste0(download_dir, '\\', 'file.txt'))
    }
    # select the file using the id
    webElem <- remDr$findElement(using = 'id', value = html_id)
    webElem$clickElement()
    # pause until the file finishes downloading
    i <- 1
    while (!file.exists(paste0(download_dir, '\\', 'file.txt')) & i <= 900) { # check to see if the file exists (but only up to 300 times)
        Sys.sleep(time = 1) # if the file doesn't exist yet, wait 1 second then check again
        i <- i + 1 # to keep track of how many times the loop runs, to prevent an infinite loop
    }
    # Rename the file, and append with the date for easier identification (may want to add in the time too?)
    file.rename(from = paste0(download_dir, '\\', 'file.txt'), to = paste0(download_dir, '\\', filename, '_', Sys.Date(), '_Raw.txt'))
    # to add the time to the filename
    # file.rename(from = 'file.txt', to = paste0('Industrial_Ad_Hoc_Reports_-_Parameter_Data_', Sys.Date(),'_', hour(Sys.time()),'.', minute(Sys.time()), '.', if(am(Sys.time())) {'AM'} else {'PM'}))
    # Delete old versions of the files (if desired)
    if (delete_old_versions == TRUE) {
        files_list <- grep(pattern = paste0('^', filename, '_'), x = list.files(download_dir), value = TRUE) # get a list of all of the files of this type (including the new one) (NOTE: ^ means: starts with..)
        # files_list_old <- files_list[files_list != paste0(filename, '_', Sys.Date(), '_Raw.txt')] # exclude the new file from the list of files to be deleted
        files_to_keep <- c(paste0(filename, '_', Sys.Date() - seq(0,7), '_Raw.txt'),
                           paste0(filename, '_', Sys.Date() - seq(0,7), '.csv')) # keep the files from the previous 7 days
        files_list_old <- files_list[!(files_list %in% files_to_keep)] # exclude the new file from the list of files to be deleted
        if (length(files_list_old) > 0) {
            file.remove(paste0(download_dir, '\\', files_list_old))
        }
        
    }
    
    # convert the file to .csv
    # Read the data as text strings into R (so that it can be checked for special characters, etc)
    dataset_lines <- readLines(paste0(download_dir, '\\', filename, '_', Sys.Date(), '_Raw.txt'))
    # Check for quotes, and remove them (to avoid problems with special characters)    
    problems <- grep(pattern = '\"*\"', x = dataset_lines) # this finds lines with quoted text - used below to remove the quotes ("t" is especially problematic, because it can get confused with a tab delimiter)
    for (i in seq_along(problems)) {
        dataset_lines[problems[i]] <- gsub(pattern = '\"*\"', replacement = '', x = dataset_lines[problems[i]]) # this removes the quotes (but keeps the text within the quotes)
    }
    # Make sure all encoding is in UTF-8
    dataset_lines <- iconv(x = dataset_lines, to = 'UTF-8') # encoding options available with: stri_enc_list(simplify = TRUE)
    dataset_lines <- str_conv(string = dataset_lines, encoding = 'UTF-8')
    # trying different methods
    # dataset_lines <- iconv(dataset_lines, from = 'ASCII', to = 'UTF-8')
    # dataset_lines <- stri_conv(str = dataset_lines, to = 'ASCII')
    # dataset_lines <- stri_conv(str = dataset_lines, to = 'UTF-8')
    # dataset_lines <- stri_conv(str = dataset_lines, from = 'ASCII', to = 'UTF-8')
    # # check
    #     table(Encoding(dataset_lines))
    #     table(stri_enc_mark(dataset_lines))
    #     table(stri_enc_isutf8(dataset_lines))
    # write the corrected dataset to a temporary file
    t <- tempfile()
    writeLines(text = dataset_lines, con = file(t, encoding = 'UTF-8'), sep = '\n')
    # read the new dataset, then close the temporary file
    # if (filename == 'Industrial_Ad_Hoc_Reports_-_Parameter_Data' | 
    #     filename == 'Industrial_Application_Specific_Data' |
    #     filename == 'Construction_Ad_Hoc_Reports_-_Parameter_Data' |
    #     filename == 'Construction_Application_Specific_Data') {
    dataset <- suppressMessages(read_tsv(file = t, col_types = cols(.default = 'c'))) # guess_max = 900000))
    # }
    # if (filename == 'Inspections' | 
    #     filename == 'Violations' |
    #     filename == 'Enforcement_Actions') {
    #    dataset <- suppressMessages(read_tsv(file = t, col_types = cols(.default = 'c')))
    #}
    unlink(t)
    
    # make sure the results are distinct (for consistency with the original dataset leave this part out)  
    # dataset <- dataset %>% distinct()
    
    # # FOR TESTING
    #     write_csv(x = dataset, path = 'TEST_Dataset.csv')
    #     dataset <- read_csv('TEST_Dataset.csv')
    
    
    # NEW STUFF - 2019-09-18
    # make some adjustments to the dataset to make fields consistent with the CA Open Data Portal for dates/times
    if (filename == 'Industrial_Ad_Hoc_Reports_-_Parameter_Data' | 
        filename == 'Industrial_Application_Specific_Data' |
        filename == 'Construction_Ad_Hoc_Reports_-_Parameter_Data' |
        filename == 'Construction_Application_Specific_Data') {
        # convert dates and times into a timestamp field that can be read by the portal - ADDED 2019-09-18
        for (counter in seq_along(fields_dates)) {
            # Get a list of the date fields in the ISO format
            dates_iso <- mdy(dataset[[fields_dates[counter]]])
            if ((filename == 'Construction_Application_Specific_Data' | 
                 filename == 'Construction_Application_Specific_Data') & 
                fields_dates[counter] == 'CERTIFICATION_DATE') {
                dates_iso <- dmy(substr(x = dataset$CERTIFICATION_DATE, start = 1, stop = 9))
            }
            # check NAs: sum(is.na(dates_iso))
            
            # Create a vector of timestamps for any date (plus associated time) fields in the dataset
            if (filename == 'Industrial_Ad_Hoc_Reports_-_Parameter_Data' | filename == 'Industrial_Application_Specific_Data') {
                timestamps <- mdy_hm(paste(dataset[[fields_dates[counter]]], dataset[[fields_times[counter]]]))
            } else if (filename == 'Construction_Ad_Hoc_Reports_-_Parameter_Data' | filename == 'Construction_Application_Specific_Data') {
                timestamps <- mdy_hms(paste(dataset[[fields_dates[counter]]], dataset[[fields_times[counter]]]))
            }
            # check NAs: sum(is.na(timestamps))
            
            # For timestamps that don't work, just use the date (times are often not in a standard format)
            timestamps[is.na(timestamps)] <- dates_iso[is.na(timestamps)]
            # check NAs: 
            print(paste0('Unconverted timestamps: ', sum(is.na(timestamps))))
            
            # Convert to text, and for timestamps that still don't work, store as '' (empty text string) - this converts to 'null' in Postgres
            timestamps <- as.character(timestamps)
            sum(is.na(timestamps))
            timestamps[is.na(timestamps)] <- ''
            # check NAs: sum(is.na(timestamps))
            
            # Insert the timestamp fields into the dataset
            dataset[,fields_timestamps[counter]] <- timestamps
            
            # convert the date fields to dates (added 2020-07-20)
            dates_iso <- as.character(dates_iso)
            dates_iso[is.na(dates_iso)] <- ''
            dataset[[fields_dates[counter]]] <- dates_iso
            
            # convert numeric fields to numeric (added 2020-07-20)
            for (counter in seq_along(fields_numeric)) {
                dataset[[fields_numeric[counter]]] <- as.numeric(dataset[[fields_numeric[counter]]])
            }
            
        }
    }
    
    if (filename == 'Inspections' | 
        filename == 'Violations' |
        filename == 'Enforcement_Actions') {
        # convert date fields into ISO format (YYYY-MM-DD)
        for (counter in seq_along(fields_dates)) {
            dates_iso <- mdy(dataset[[fields_dates[counter]]])
            
            dates_iso <- as.character(dates_iso)
            # sum(is.na(dates_iso))
            dates_iso[is.na(dates_iso)] <- ''
            
            dataset[[fields_dates[counter]]] <- dates_iso
        }
        # # convert time fields into character strings (if not already)
        # for (counter in seq_along(fields_times)) {
        #     dataset[[fields_times[counter]]] <- as.character(dataset[[fields_times[counter]]])
        # }
        # convert numeric fields to numeric
        for (counter in seq_along(fields_numeric)) {
            dataset[[fields_numeric[counter]]] <- as.numeric(dataset[[fields_numeric[counter]]])
        }
        
        # get location data (from the datasets: Industrial_Application_Specific_Data and Construction_Application_Specific_Data)
        if (!exists('location_data')) {
            ind_site_data <- read_csv(paste0(download_dir, '\\', 'Industrial_Application_Specific_Data_', 
                                             Sys.Date(), '.csv'), 
                                      guess_max = 999999) 
            names(ind_site_data) <- gsub('FACILITY', 'PLACE', names(ind_site_data))
            ind_site_data <- ind_site_data %>% rename(REGIONAL_BOARD = REGION_BOARD)
            con_site_data <- read_csv(paste0(download_dir, '\\', 'Construction_Application_Specific_Data_', 
                                             Sys.Date(), '.csv'), 
                                      guess_max = 999999)
            names(con_site_data) <- gsub('SITE', 'PLACE', names(con_site_data))
            con_site_data <- con_site_data %>% rename(REGIONAL_BOARD = REGION)
            
            tf_1 <- names(ind_site_data) %in% names(con_site_data)
            ind_site_data <- ind_site_data %>% select(names(ind_site_data)[tf_1])
            
            tf_2 <- names(con_site_data) %in% names(ind_site_data)
            con_site_data <- con_site_data %>% select(names(con_site_data)[tf_2])
            
            location_data <- bind_rows(ind_site_data, con_site_data)
            location_data <- location_data %>% 
                select(-c('PLACE_CONTACT_FIRST_NAME', 'PLACE_CONTACT_LAST_NAME', 'PLACE_TITLE',
                          'PLACE_PHONE', 'PLACE_EMAIL', 'CERTIFIER_BY', 'CERTIFIER_TITLE',
                          'STATUS', 'NOI_PROCESSED_DATE', 'NOT_EFFECTIVE_DATE',
                          'CERTIFICATION_DATE', 'NOI_PROCESSED_TIMESTAMP', 
                          'NOT_EFFECTIVE_TIMESTAMP',
                          'COUNTY', 'CERTIFICATION_TIMESTAMP'))
            location_data <- location_data %>% filter(!is.na(APP_ID) & !is.na(WDID))
            location_data <- location_data %>% distinct()
            location_data <- location_data %>% 
                mutate(APP_ID = as.character(APP_ID))
            # check whether the combination of APP_ID and WDID are unique in the location data
            # check_loc_data <- location_data %>%
            #     group_by(APP_ID, WDID) %>%
            #     summarize(count = n()) %>%
            #     arrange(desc(count))
            # range(check_loc_data$count) # should be min and max of 1
        }
        # join location data to the current dataset
        dataset <- left_join(x = dataset, 
                             y = location_data, 
                             by = c('APP_ID', 'WDID'))
        
        # re-arrange some fields so that WDID and APP_ID are always the first two columns
        if (filename == 'Inspections') {
            dataset <- dataset %>% 
                select(-REGION) %>% 
                {.}
        }
        if (filename == 'Violations') {
            dataset <- dataset %>% 
                relocate(WDID, APP_ID) %>% 
                {.}
        }
        if (filename == 'Enforcement_Actions') {
            dataset <- dataset %>% # no changes
                {.}
        }
        
    }
    
    # Convert missing values in text fields to 'NA' (to avoid converting to NaN) !!!!!!!!!!!
    # from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
    # dataset <- dataset %>% mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))
    dataset <- dataset %>% mutate_if(is.character, ~replace(., is.na(.), 'NA'))
    
    
    # write the revised dataset to a csv file
    write_csv(x = dataset, 
                     path = paste0(download_dir, '\\', filename, '_', Sys.Date(), '.csv'), na = 'NaN')
    rm(dataset_lines, problems, dataset, t)
}


### download the files ----
tryCatch(
    for (i in seq_along(dataset_list)) {
        SMARTS_data_download(filename = dataset_list[[i]]$filename, 
                             html_id = dataset_list[[i]]$html_id, 
                             delete_old_versions = delete_old_versions, 
                             fields_dates = dataset_list[[i]]$date_fields, 
                             fields_times = dataset_list[[i]]$time_fields, 
                             fields_timestamps = dataset_list[[i]]$timestamp_names,
                             fields_numeric = dataset_list[[i]]$numeric_fields)
    }, 
    error = function(e) {
        error_message <- 'downloading files'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        remDr$close()
        shell.exec(file = 'Stop.bat')
        stop(e)
    }
)

# close windows (maybe not needed) ----
tryCatch(
    {
        # remDr$switchToWindow(noiWindow[[1]])
        myswitch(remDr = remDr, windowId = noiWindow[[1]])
        remDr$closeWindow()
        # remDr$switchToWindow(homeWindow[[1]])
        myswitch(remDr = remDr, windowId = homeWindow[[1]])
    },
    error = function(e) {
        error_message <- 'navigating after downloads'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        remDr$close()
        shell.exec(file = 'Stop.bat')
        stop(e)
    }
)



# # create combined files - NOTE: Might want to first use facility info from active facilities, then use info from inactive facilities for those that don't get a match (some sites are listed twice in the facilities info files, one active and one inactive)
#     # Facilities
#         ind.facilities <- read_csv(paste0(dataset_list$dataset2$filename, '_', Sys.Date(), '.csv'), guess_max = 50000)
#         ind.results <- read_csv(paste0(dataset_list$dataset1$filename, '_', Sys.Date(), '.csv'), guess_max = 50000)
#         con.facilities <- read_csv(paste0(dataset_list$dataset4$filename, '_', Sys.Date(), '.csv'), guess_max = 50000)
#         con.results <- read_csv(paste0(dataset_list$dataset3$filename, '_', Sys.Date(), '.csv'), guess_max = 50000)
# 
# 
#         ind.facilities <- ind.facilities %>% select(WDID, REGION_BOARD, COUNTY, FACILITY_LATITUDE, FACILITY_LONGITUDE, PERMIT_TYPE, APP_ID, STATUS)
#         con.facilities <- con.facilities %>% select(WDID, REGION, COUNTY, SITE_LATITUDE, SITE_LONGITUDE, PERMIT_TYPE, APP_ID, STATUS)
#         names(ind.facilities) <- gsub(pattern = 'FACILITY_', replacement = '', x = names(ind.facilities))
#         names(ind.facilities) <- gsub(pattern = '_BOARD', replacement = '', x = names(ind.facilities))
#         names(con.facilities) <- gsub(pattern = 'SITE_', replacement = '', x = names(con.facilities))
#         all.facilities <- bind_rows(ind.facilities, con.facilities)
#         write_csv(x = all.facilities, path = paste0('All_Facilities_', Sys.Date(), '.csv'))
#         rm(list = c('ind.facilities', 'con.facilities'))
# 
#     # Industrial
#         # first join just the active facility info
#         ind.active <- ind.facilities %>% filter(STATUS == 'Active')
#         ind.terminated <- ind.facilities %>% filter(STATUS == 'Terminated')
#         ind.combined <- left_join(x = ind.results, y = ind.active)
#         ind.combined.matched <- ind.combined %>% filter(!is.na(ind.combined$STATUS))
#         ind.notMatched <- ind.results[is.na(ind.combined$STATUS),]
#         ind.combined.notMatched <- left_join(x = ind.notMatched, y = ind.facilities)
#         ind.combined.final <- bind_rows(ind.combined.matched, ind.combined.notMatched)
#         write_csv(x = ind.combined.final, path = paste0('Industrial_Combined_', Sys.Date(), '.csv'))
#         # simple join
#             z <- left_join(ind.results %>% distinct(), ind.facilities %>% group_by(WDID) %>% select(-PERMIT_TYPE, -APP_ID) %>% distinct())
#         # compare
#             identical(ind.combined.final, z)
#             nrow(z)
#             nrow(ind.combined.final)
# 
#     # Construction
#         con.combined <- left_join(x = con.results, y = con.facilities, by = c('WDID'))
#         write_csv(x = con.combined, path = paste0('Construction_Combined_', Sys.Date(), '.csv'))


# # STEP 4: Download Report data (datasets available by clicking on a 'Export to Excel' button)
#     # define a function to download a given dataset from the reports pages
#         SMARTS_form_download <- function(reports_page_id, report_id, run_report_id, export_excel_id, smarts_file_name, smarts_file_type,
#                                          filename, portal_node, delete_old_versions = FALSE) { # NOTE: To find the html identifiers of the button/link in the html code use the 'developer' tool in the browser
#             # this automatically downloads the file to the default download location for the browser, set above
#             # NOTE: Files downloaed from SMARTS reports are automatically named sample.xls, so check to make sure there isn't already an un-named file (sample.xls) in 
#             # this location  - if so, delete it (otherwise the newly downloaded file will be appended with a number, and the versions might get confused)
#             if (file.exists(smarts_file_name)) {
#                 unlink(smarts_file_name)
#             }
#             # Open the link to the relevant reports page 
#                 webElem <- remDr$findElement(using = 'id', value = reports_page_id)
#                 webElem$clickElement()
#                 allWins <- unlist(remDr$getWindowHandles())
#                 reportWindow <- allWins[!allWins %in% homeWindow[[1]]]
#                 # Switch to the reports page
#                     # remDr$switchToWindow(reportWindow) # this no longer works... need to use the custom function below, from: https://github.com/ropensci/RSelenium/issues/143
#                     
#                     myswitch <- function (remDr, windowId) {
#                         qpath <- sprintf("%s/session/%s/window", remDr$serverURL,
#                                          remDr$sessionInfo[["id"]])
#                         remDr$queryRD(qpath, "POST", qdata = list(handle = windowId))
#                     }
#                     myswitch(remDr = remDr, windowId = reportWindow[[1]])
#             # select the report link
#                 webElem <- remDr$findElement(using = 'id', value = report_id)
#                 webElem$clickElement()
#             # select the run report button
#                 webElem <- remDr$findElement(using = 'id', value = run_report_id)
#                 webElem$clickElement()
#                 # Alt Method
#                 # NOTE: It's also possible to do this 'manually' (i.e., by recreating the mouse actions and button clicks), like this:
#                 loc <- webElem$getElementLocation()
#                 remDr$mouseMoveToLocation(webElement = webElem)
#                 remDr$click()
# 
#             # select the Export To Excel button
#                 webElem <- remDr$findElement(using = 'id', value = export_excel_id)
#                 webElem$clickElement()
#             # pause until the file finishes downloading
#             i <- 1
#             while (!file.exists(smarts_file_name) & i <= 300) { # check to see if the file exists (but only up to 300 times)
#                 Sys.sleep(time = 1) # if the file doesn't exist yet, wait 1 second then check again
#                 i <- i + 1 # to keep track of how many times the loop runs, to prevent an infinite loop
#             }
#             # Rename the file, and append with the date for easier identification (may want to add in the time too?)
#                 file.rename(from = smarts_file_name, to = paste0(filename, '-', Sys.Date(), '.', smarts_file_type))
#             # to add the time to the filename
#                 # file.rename(from = 'file.txt', to = paste0('Industrial_Ad_Hoc_Reports_-_Parameter_Data_', Sys.Date(),'_', hour(Sys.time()),'.', minute(Sys.time()), '.', if(am(Sys.time())) {'AM'} else {'PM'}))
#             # Delete old versions of the files (if desired)
#             if (delete_old_versions == TRUE) {
#                 files.list <- grep(pattern = paste0('^', filename), x = list.files(), value = TRUE) # get a list of all of the files of this type (including the new one) (NOTE: ^ means: starts with..)
#                 files.list.old <- files.list[files.list != paste0(filename, '_', Sys.Date(), '.xls')] # exclude the new file from the list of files to be deleted
#                 file.remove(files.list.old)
#             }
#             # convert the file to .csv
#                 report.result <- readHTMLTable(paste0(filename, '_', Sys.Date(), '.xls'))
#                 # report.result <- list.clean(report.result, fun = is.null, recursive = FALSE)
#                 # n.rows <- unlist(lapply(report.result, function(t) dim(t)[1]))
#                 report.result <- report.result[[1]]
#                 # check last row (may be blank)
#                     check.last.row <- apply(report.result[nrow(report.result),], 2, function(x) {x == ''})
#                     if (sum(!check.last.row) == 0) {
#                         report.result <- report.result[-nrow(report.result), ]
#                     }
#                 # write to csv
#                     # NEED TO CHECK FOR DOUBLE SPACES, ETC BEFORE WRITING FILE
#                     for (i in 1:3) {
#                         report.result <- apply(X = report.result, MARGIN = 2, FUN = function(x) {gsub(pattern = '  ', replacement = ' ', x = x)})
#                         report.result <- as.data.frame(report.result)
#                     }
#                     report.result <- as_tibble(report.result)
#                     report.result <- clean_names(report.result)
#                 # Write File
#                     write_csv(x = report.result, path = paste0(filename, '_', Sys.Date(), '.csv'))
#                     
#             # # NOTE - DOESN'T LOOK LIKE THIS PART IS NEEDED
#             # # Read the data as text strings into R (so that it can be checked for special characters, etc)
#             #     write_tsv(x = report.result, path = paste0(filename, '_', Sys.Date(), '_Raw.txt'))
#             #     dataset_lines <- readLines(paste0(filename, '_', Sys.Date(), '_Raw.txt'))
#             # # Check for quotes, and remove them (to avoid problems with special characters)    
#             #     problems <- grep(pattern = '\"*\"', x = dataset_lines) # this finds lines with quoted text - used below to remove the quotes ("t" is especially problematic, because it can get confused with a tab delimiter)
#             #     for (i in seq(length(problems))) {
#             #         dataset_lines[problems[i]] <- gsub(pattern = '\"*\"', replacement = '', x = dataset_lines[problems[i]]) # this removes the quotes (but keeps the text within the quotes)
#             #     }
#             # # Make sure all encoding is in UTF-8
#             #     dataset_lines <- iconv(x = dataset_lines, to = 'UTF-8') # encoding options available with: stri_enc_list(simplify = TRUE)
#             #     dataset_lines <- str_conv(string = dataset_lines, encoding = 'UTF-8')
#             # # # check
#             # #     table(Encoding(dataset_lines))
#             # #     table(stri_enc_mark(dataset_lines))
#             # #     table(stri_enc_isutf8(dataset_lines))
#             # # write the corrected dataset to a temporary file
#             #     t <- tempfile()
#             #     writeLines(text = dataset_lines, con = file(t, encoding = 'UTF-8'), sep = '\n')
#             # # read the new dataset, then close the temporary file
#             #     dataset <- suppressMessages(read_tsv(file = t, guess_max = 10000))
#             #     unlink(t)
#             # # write the corrected dataset to a pipe delimited txt file
#             #     write_csv(x = dataset, path = paste0(filename, '_', Sys.Date(), '_2.csv'))
#             #     rm(dataset_lines, problems, dataset, t)
#             # # check
#             #     # z_check_1 <- read_csv(paste0(filename, '_', Sys.Date(), '.csv'), guess_max = 10000)
#             #     # z_check_2 <- read_csv(paste0(filename, '_', Sys.Date(), '_2.csv'), guess_max = 10000)
#             #     # identical(z_check_1, z_check_2)
#             
#                 
#                 
#             # close the reports window
#                 remDr$closeWindow()
#                 # remDr$switchToWindow(homeWindow[[1]])
#                 myswitch(remDr = remDr, windowId = homeWindow[[1]])
#         }








# # Download the files
#     for (i in seq(length(forms_datasets_list))) {
#         SMARTS_form_download(reports_page_id = forms_datasets_list[[i]]$reports_page_id,
#                              report_id = forms_datasets_list[[i]]$report_id,
#                              run_report_id = forms_datasets_list[[i]]$run_report_id,
#                              export_excel_id = forms_datasets_list[[i]]$export_excel_id,
#                              smarts_file_name = forms_datasets_list[[i]]$smarts_file_name,
#                              smarts_file_type = forms_datasets_list[[i]]$smarts_file_type,
#                              filename = forms_datasets_list[[i]]$filename,
#                              portal_node = forms_datasets_list[[i]]$portal_node,
#                              delete_old_versions = delete_old_versions)
#     }



# 6 - close the connection ------------------------------------------------
tryCatch(
    {
        remDr$close()
        # rsD$server$stop(e) # from the old method
        rm(list = c('remDr'))#'eCaps', , 'SMARTS_url', 'rsD'))
        gc()
        
        shell.exec(file = 'Stop.bat') # this closes the java window
    },
    error = function(e) {
        error_message <- 'closing Selenium connection/server'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)




# 7 - load data to portal -----------------------------------------------------

## run function to upload the formatted data from SMARTS to the data.ca.gov portal ----
### loops through all of the datasets defined in the 'dataset_list' variable in the script: 1_FilesList.R
tryCatch(
    {
        ### set the ckan defaults ----
        ckanr_setup(url = 'https://data.ca.gov/', key = portal_key) 
        
        for (i in seq(length(dataset_list))) {
            resourceID <- dataset_list[[i]]$resource_id
            filename <- dataset_list[[i]]$filename
            ckan_resource_info <- resource_show(id = resourceID, as = 'table') # resource
            # check the connection
            # current_dataportal_filename <- gsub(pattern = '.*/download/', replacement = '', x = ckan_resource_info$url)
            # print(current_dataportal_filename) # this is just a test to make sure the API connection is successful
            fileToUpload <- paste0(download_dir, '\\', filename, '_', Sys.Date(), '.csv')
            file_upload <- resource_update(id = resourceID, path = fileToUpload)
            
            # # output the result of the upload process to a log file called: _DataPortalUpload-Log.txt
            # # check to see if the log file exists - if not, create it
            # if (file.exists('_DataPortalUpload-Log.txt') == FALSE) {
            #     file.create('_DataPortalUpload-Log.txt')
            # }
            # # write the result to the log file, depending on the current data portal filename
            # file_name_check <- paste0(filename, '_', Sys.Date(), '.csv')
            # new_dataportal_filename <- gsub(pattern = '.*/download/', replacement = '', x = file_upload$url)
            # if (tolower(new_dataportal_filename) == tolower(file_name_check)) {
            #     write_lines(x = paste0(Sys.time(), ' - ', file_name_check, ': ', 'Completed Upload'), 
            #                 file = '_DataPortalUpload-Log.txt', append = TRUE)   
            # } else {
            #     write_lines(x = paste0(Sys.time(), ' - ', file_name_check, ': ', 'Upload NOT completed'), 
            #                 file = '_DataPortalUpload-Log.txt', append = TRUE)
            # }
        }
    },
    error = function(e) {
        error_message <- 'uploading data (sending data to portal)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    } 
)
