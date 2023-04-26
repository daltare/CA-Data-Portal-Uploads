# NOTE: if this stops working with an error message related to the Chrome WebDriver, take the following steps:
# 1. Check the version of Chrome currently installed
# 2. Go to the following website and download/save the corresponding version of the Chrome WebDriver: https://sites.google.com/a/chromium.org/chromedriver/downloads
# 3. Unzip the folder, and rename the unzipped folder with the version of the WebDriver
# 4. Copy that folder to the following location: C:\Users\daltare\AppData\Local\binman\binman_chromedriver\win32 (there should be old versions of the driver there too)
# 5. Go to the 'Start_Server.bat' file, right click on it and open with a text editor, then find the part relating to the Chrome driver and change the version number (i.e. folder name) to the version you just downloaded - e.g. in this part, change the "77.0.3865.40" to the new version:
# -Dwebdriver.chrome.driver="C:\Users\daltare\AppData\Local\binman\binman_chromedriver\win32\77.0.3865.40/chromedriver.exe"




# load packages -----------------------------------------------------------
{
    library(RSelenium)
    library(methods) # it seems that this needs to be called explicitly to avoid an error for some reason
    library(XML)
    library(tidyverse)
    library(janitor)
    library(lubridate)
    library(glue)
    library(sendmailR)
    library(blastula)
    library(binman)
    library(pingr)
    library(ckanr)
    library(wdman)
    library(here)
}



# 1 - user input --------------------------------------------------------------
## set download directory ----
##(i.e., where to save any downloaded files)
download_dir <- 'C:\\David\\_CA_data_portal\\SMARTS'

## delete old files
delete_old_versions = TRUE # whether or not to delete previous versions of each dataset - FALSE means to keep the old versions
# NOTE: currently set to keep the versions from the previous 7 days if TRUE

## enter the email address to send warning emails from
### NOTE - if sending from a personal email address, you'll have to update the credentials -- see below
email_from <- 'daltare.swrcb@gmail.com' # 'david.altare@waterboards.ca.gov' # "gisscripts-noreply@waterboards.ca.gov"
credentials_file <- 'gmail_creds' # this is the credentials file to be used (corresponds to the email_from address)

## enter the email address (or addresses) to send warning emails to
email_to <- 'david.altare@waterboards.ca.gov' # c('david.altare@waterboards.ca.gov', 'waterdata@waterboards.ca.gov')

## get data portal API key (saved in the local environment)
### (it's available on data.ca.gov by going to your user profile)
portal_key <- Sys.getenv('data_portal_key')



# 2- enter info about datasets to be downloaded ------------------------------
## The filename is the name of the file that will be output (the current date will also be appended to the name) - using the tile of the link to the dataset on the SMARTS webpage as the filename, to make it easier to keep track of the data source
## The html_id is the identifier of the button/link for the given dataset in the html code on the SMARTS website (use the 'developer' too in the browser to find this in the html code)
dataset_list <- list(dataset1 = list(filename = 'Industrial_Ad_Hoc_Reports_-_Parameter_Data', 
                                     html_id = 'intDataFileDowloaddataFileForm:industrialRawDataLink',
                                     resource_id = '7871e8fe-576d-4940-acdf-eca0b399c1aa',
                                     date_fields = c('SAMPLE_DATE', 'DISCHARGE_START_DATE'), # NOTE: The number of items in this field should be the same as the number of items in the following two fields
                                     time_fields = c('SAMPLE_TIME', 'DISCHARGE_START_TIME'),
                                     timestamp_names = c('SAMPLE_TIMESTAMP', 'DISCHARGE_START_TIMESTAMP'),
                                     numeric_fields = c('REPORTING_YEAR', 'MONITORING_LATITUDE', 
                                                        'MONITORING_LONGITUDE', 'RESULT', 
                                                        'MDL', 'RL')),
                     dataset2 = list(filename = 'Industrial_Application_Specific_Data', 
                                     html_id = 'intDataFileDowloaddataFileForm:industrialAppLink',
                                     resource_id = '33e69394-83ec-4872-b644-b9f494de1824',
                                     date_fields = c('NOI_PROCESSED_DATE', 'NOT_EFFECTIVE_DATE', 'CERTIFICATION_DATE'), # NOTE: The number of items in this field should be the same as the number of items in the following two fields
                                     time_fields = c('', '', ''),
                                     timestamp_names = c('NOI_PROCESSED_TIMESTAMP', 'NOT_EFFECTIVE_TIMESTAMP', 'CERTIFICATION_TIMESTAMP'),
                                     numeric_fields = c('FACILITY_LATITUDE', 'FACILITY_LONGITUDE', 
                                                        'FACILITY_TOTAL_SIZE', 'FACILITY_AREA_ACTIVITY', 
                                                        'PERCENT_OF_SITE_IMPERVIOUSNESS')),
                     dataset3 = list(filename = 'Construction_Ad_Hoc_Reports_-_Parameter_Data', 
                                     html_id = 'intDataFileDowloaddataFileForm:constructionAdhocRawDataLink',
                                     resource_id = '0c441948-5bb9-4d50-9f3c-ca7dab256056', 
                                     date_fields = c('SAMPLE_DATE', 'EVENT_START_DATE', 'EVENT_END_DATE'), # NOTE: The number of items in this field should be the same as the number of items in the following two fields
                                     time_fields = c('SAMPLE_TIME', '', ''),
                                     timestamp_names = c('SAMPLE_TIMESTAMP', 'EVENT_START_TIMESTAMP', 'EVENT_END_TIMESTAMP'),
                                     numeric_fields = c('REPORT_YEAR', 'RAINFALL_AMOUNT', 
                                                        'BUSINESS_DAYS', 'MONITORING_LATITUDE', 
                                                        'MONITORING_LONGITUDE', 'PERCENT_OF_TOTAL_DISCHARGE', 
                                                        'RESULT', 'MDL', 'RL')),    
                     dataset4 = list(filename = 'Construction_Application_Specific_Data', 
                                     html_id = 'intDataFileDowloaddataFileForm:constructionAppLink',
                                     resource_id = '8a0ed456-ca69-4b29-9c5b-5de3958dc963', 
                                     date_fields = c('NOI_PROCESSED_DATE', 'NOT_EFFECTIVE_DATE', 'CERTIFICATION_DATE',
                                                     'CONSTRUCTION_COMMENCEMENT_DATE', 'COMPLETE_GRADING_DATE', 'COMPLETE_PROJECT_DATE'), # NOTE: The number of items in this field should be the same as the number of items in the following two fields
                                     time_fields = c('', '', '', '', '', ''),
                                     timestamp_names = c('NOI_PROCESSED_TIMESTAMP', 'NOT_EFFECTIVE_TIMESTAMP', 'CERTIFICATION_TIMESTAMP',
                                                         'CONSTRUCTION_COMMENCEMENT_TIMESTAMP', 'COMPLETE_GRADING_TIMESTAMP', 'COMPLETE_PROJECT_TIMESTAMP'),
                                     numeric_fields = c('SITE_LATITUDE', 'SITE_LONGITUDE', 
                                                        'SITE_TOTAL_SIZE', 'SITE_TOTAL_DISTURBED_ACREAGE', 
                                                        'PERCENT_TOTAL_DISTURBED', 'IMPERVIOUSNESS_BEFORE', 
                                                        'IMPERVIOUSNESS_AFTER', 'R_FACTOR', 
                                                        'K_FACTOR', 'LS_FACTOR', 
                                                        'WATERSHED_EROSION_ESTIMATE')),
                     dataset5 = list(filename = 'Inspections', # to add a new dataset, enter here and un-comment these lines
                                     html_id = 'intDataFileDowloaddataFileForm:inspectionLink',
                                     resource_id = '33047e47-7d44-46aa-9e0f-1a0f1b0cad66',
                                     date_fields = c('INSPECTION_DATE'),
                                     time_fields = c('INSPECTION_START_TIME', 'INSPECTION_END_TIME'),
                                     timestamp_fields = c(),
                                     numeric_fields = c('COUNT_OF_VIOLATIONS')),
                     dataset6 = list(filename = 'Violations', # to add a new dataset, enter here and un-comment these lines
                                     html_id = 'intDataFileDowloaddataFileForm:violationLink',
                                     resource_id = '9b69a654-0c9a-4865-8d10-38c55b1b8c58',
                                     date_fields = c('OCCURRENCE_DATE', 'DISCOVERY_DATE'),
                                     time_fields = c(),
                                     timestamp_fields = c(),
                                     numeric_fields = c()),
                     dataset7 = list(filename = 'Enforcement_Actions', # to add a new dataset, enter here and un-comment these lines
                                     html_id = 'intDataFileDowloaddataFileForm:enfocementActionLink',
                                     resource_id = '9cf197f4-f1d5-4d43-b94b-ccb155ef14cf',
                                     date_fields = c('ISSUANCE_DATE', 'DUE_DATE', 'ACL_COMPLAINT_ISSUANCE_DATE', 
                                                     'ADOPTION_DATE', 'COMPLIANCE_DATE', 'EPL_ISSUANCE_DATE', 
                                                     'RECEIVED_DATE', 'WAIVER_RECEIVED_DATE'),
                                     time_fields = c(),
                                     timestamp_fields = c(),
                                     numeric_fields = c('ECONOMIC_BENEFITS', 'TOTAL_MAX_LIABILITY', 'STAFF_COSTS', 
                                                        'INITIAL_ASSESSMENT', 'TOTAL_ASSESSMENT', 'RECEIVED_AMOUNT', 
                                                        'SPENT_AMOUNT', 'BALANCE_DUE', 'COUNT_OF_VIOLATIONS'))
)



# 3 - setup automated email -----------------------------------------------
## create credentials file (only need to do this once) ----

### gmail credentials ----
#### NOTE - for gmail, you have to create an 'App Password' and use that 
#### instead of your normal password - see: 
#### (https://support.google.com/accounts/answer/185833?hl=en) 
#### Background here:
#### https://github.com/rstudio/blastula/issues/228 
# create_smtp_creds_file(file = credentials_file,
#                        user = email_from,
#                        provider = 'gmail'
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

Here's the error message from R: *{glue_collapse(error_msg_r, sep = ' | ')}*

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
            credentials = creds_file(credentials_file)
            # credentials = creds_key("outlook_key")
        )
    
    ### send email via sendmailR (for use on GIS scripting server) ----
    # from <- email_from
    # to <- email_to
    # sendmail(from,to,subject,body,control=list(smtpServer= ""))
    
    print('sent automated email')
}



# 4 - Setup RSelenium --------------------------------------------------------
tryCatch(
    {
        source(here('start_selenium.R'))
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
        
        print('Downloading data from SMARTS')
        Sys.sleep(10)
        
        ## Navigate to SMARTS homepage ----
        SMARTS_url <- "https://smarts.waterboards.ca.gov/smarts/SwPublicUserMenu.xhtml"
        remDr$navigate(SMARTS_url)
        Sys.sleep(10)
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
        Sys.sleep(2)
        webElem$clickElement()
        Sys.sleep(10)
        allWins <- unlist(remDr$getWindowHandles())
        Sys.sleep(2)
        noiWindow <- allWins[!allWins %in% homeWindow[[1]]]
        Sys.sleep(2)
        
        ### Switch to the "Download NOI Data..." page ----
        # remDr$switchToWindow(noiWindow) # this no longer works... need to use the custom function below, from: https://github.com/ropensci/RSelenium/issues/143
        myswitch <- function (remDr, windowId) 
        {
            qpath <- sprintf("%s/session/%s/window", remDr$serverURL, 
                             remDr$sessionInfo[["id"]])
            remDr$queryRD(qpath, "POST", qdata = list(handle = windowId))
        }
        myswitch(remDr = remDr, windowId = noiWindow[[1]])
        Sys.sleep(2)
        
        ### find and select the 'Select Regional Board' dropdown box ----
        webElem <- remDr$findElement(using = 'id', value = 'intDataFileDowloaddataFileForm:intDataDumpSelectOne')
        Sys.sleep(2)
        
        ### Set the dropdown value to 'State Board'
        webElem$sendKeysToElement(list('State Board', key = 'enter'))
        Sys.sleep(2)
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
    Sys.sleep(2)
    # Rename the file, and append with the date for easier identification (may want to add in the time too?)
    file.rename(from = paste0(download_dir, '\\', 'file.txt'), to = paste0(download_dir, '\\', filename, '_', Sys.Date(), '_Raw.txt'))
    Sys.sleep(2)
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
    Sys.sleep(2)
    
    # convert the file to .csv
    ## NEW (MORE SIMPLE) METHOD (2021-10-05) ----
    dataset <- read_tsv(paste0(download_dir, '\\', filename, '_', Sys.Date(), '_Raw.txt'),
                        col_types = cols(.default = col_character()))
    Sys.sleep(2)
    ### ensure all records are in UTF-8 format, convert if not ----
    dataset <- dataset %>%
        # map_df(~iconv(., to = 'UTF-8')) %>% # this is probably slower
        mutate(across(everything(), 
                      ~iconv(., to = 'UTF-8'))) %>% 
        {.}
    
    ### remove characters for quotes, tabs, returns, pipes, etc ----
    remove_characters <- c('\"|\t|\r|\n|\f|\v|\\|')
    dataset <- dataset %>%
        map_df(~str_replace_all(., remove_characters, ' '))
    
    
    ## OLD METHOD ----
    # # Read the data as text strings into R (so that it can be checked for special characters, etc)
    # dataset_lines <- readLines(paste0(download_dir, '\\', filename, '_', Sys.Date(), '_Raw.txt'))
    # # Check for quotes, and remove them (to avoid problems with special characters)    
    # problems <- grep(pattern = '\"*\"', x = dataset_lines) # this finds lines with quoted text - used below to remove the quotes ("t" is especially problematic, because it can get confused with a tab delimiter)
    # for (i in seq_along(problems)) {
    #     dataset_lines[problems[i]] <- gsub(pattern = '\"*\"', replacement = '', x = dataset_lines[problems[i]]) # this removes the quotes (but keeps the text within the quotes)
    # }
    # # Make sure all encoding is in UTF-8
    # dataset_lines <- iconv(x = dataset_lines, to = 'UTF-8') # encoding options available with: stri_enc_list(simplify = TRUE)
    # dataset_lines <- str_conv(string = dataset_lines, encoding = 'UTF-8')
    # # trying different methods
    # # dataset_lines <- iconv(dataset_lines, from = 'ASCII', to = 'UTF-8')
    # # dataset_lines <- stri_conv(str = dataset_lines, to = 'ASCII')
    # # dataset_lines <- stri_conv(str = dataset_lines, to = 'UTF-8')
    # # dataset_lines <- stri_conv(str = dataset_lines, from = 'ASCII', to = 'UTF-8')
    # # # check
    # #     table(Encoding(dataset_lines))
    # #     table(stri_enc_mark(dataset_lines))
    # #     table(stri_enc_isutf8(dataset_lines))
    # # write the corrected dataset to a temporary file
    # t <- tempfile()
    # writeLines(text = dataset_lines, con = file(t, encoding = 'UTF-8'), sep = '\n')
    # # read the new dataset, then close the temporary file
    # # if (filename == 'Industrial_Ad_Hoc_Reports_-_Parameter_Data' | 
    # #     filename == 'Industrial_Application_Specific_Data' |
    # #     filename == 'Construction_Ad_Hoc_Reports_-_Parameter_Data' |
    # #     filename == 'Construction_Application_Specific_Data') {
    # dataset <- suppressMessages(read_tsv(file = t, col_types = cols(.default = 'c'))) # guess_max = 900000))
    # }
    # if (filename == 'Inspections' | 
    #     filename == 'Violations' |
    #     filename == 'Enforcement_Actions') {
    #    dataset <- suppressMessages(read_tsv(file = t, col_types = cols(.default = 'c')))
    #}
    # unlink(t)
    
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
        Sys.sleep(5)
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



# 6 - close the connection ------------------------------------------------
tryCatch(
    {
        remDr$close()
        # rsD$server$stop(e) # from the old method
        rm(list = c('remDr'))#'eCaps', , 'SMARTS_url', 'rsD'))
        gc()
        
        shell.exec(file = here('Stop.bat')) # this closes the java window
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
        print('Uploading datasets to the CA open data portal (data.ca.gov)')
        
        ### set the ckan defaults ----
        ckanr_setup(url = 'https://data.ca.gov/', key = portal_key) 
        
        for (i in seq(length(dataset_list))) {
            resourceID <- dataset_list[[i]]$resource_id
            filename <- dataset_list[[i]]$filename
            
            print(glue('Uploading file: {filename}'))
            
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
        print('Upload complete')
    },
    error = function(e) {
        error_message <- 'uploading data (sending data to portal)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    } 
)
