# NOTE: To schedule this script to run automatically, go to 'Addins' and 'Schedule R scripts on...', then select 
# the file that calls this script ("C:\\David\\Open_Data_Project\\__CA_DataPortal\\_Call_Scripts\\Call_SurfWater_Script.R.R")
# and set the time/date option (make sure the date format is %m/%d/%Y)



# load packages -----------------------------------------------------------
library(ckanr) # this lets you work with the CKAN portal
library(tidyverse)
library(janitor)
library(lubridate)
library(blastula) # for sending automated email
library(sendmailR)
library(glue)



# user inputs -------------------------------------------------------------
## define direct link to the data
file_link <- 'https://intapps.waterboards.ca.gov/downloadFile/flatFilesEwrims.xhtml?fileName=ewrims_flat_file.csv'

## define data portal resource ID
resourceID <- '151c067a-088b-42a2-b6ad-99d84b48fb36' # https://data.ca.gov/dataset/water-rights/resource/151c067a-088b-42a2-b6ad-99d84b48fb36

## get data portal API key
#### key is saved in the local environment (it's available on data.ca.gov by going to your user profile)
portal_key <- Sys.getenv('data_portal_key')
# portal_key <- '' # for GIS scripting server, enter key here

## define location where files will be saved
file_save_location <- 'C:\\Users\\daltare\\Documents\\ca_data_portal_temp\\Water-Rights\\'
# file_save_location <- 'D:\\Data\\Scripts\\R\\water_rights_update\\' # for GIS scripting server

## enter the email address to send warning emails from
### NOTE - if sending from a personal email address, you'll have to update the credentials -- see below
email_from <- 'daltare.swrcb@gmail.com' # 'david.altare@waterboards.ca.gov' # "gisscripts-noreply@waterboards.ca.gov"
credentials_file <- 'gmail_creds' # this is the credentials file to be used (corresponds to the email_from address)
# email_from <- 'gisscripts-noreply@waterboards.ca.gov' # for GIS scripting server

## enter the email address (or addresses) to send warning emails to
email_to <- 'david.altare@waterboards.ca.gov' 
# email_to <- c('david.altare@waterboards.ca.gov', 'waterdata@waterboards.ca.gov') # for GIS scripting server



# setup automated email -----------------------------------------------
## create credentials file (only need to do this once, and only if sending from a personal email account) ----

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
        
There was an error uploading the Water Rights Master Flat File data to the data.ca.gov portal on {Sys.Date()}.

------
                
The process failed at this step: *{error_msg}*

Here's the error message from R: *{glue_collapse(error_msg_r, sep = ' | ')}*

------
                
Here's the link to the dataset on the data portal: https://data.ca.gov/dataset/water-rights/resource/151c067a-088b-42a2-b6ad-99d84b48fb36
                
Here's the link to the flat file with the source data: https://intapps.waterboards.ca.gov/downloadFile/faces/flatFilesEwrims.xhtml  (File Name = ewrims_flat_file.csv)"                
    )
    
    #### footer ----
    footer <- glue("Email sent on {date_time}.")
    
    #### subject ----
    subject <- "Data Portal Upload Error - Water Rights Master Flat File"
    
    ### create email ----
    email <- compose_email(
        body = md(body),
        footer = md(footer)
    )
    
    
    ### send email via blastula (using credentials file) ----
    email %>%
        smtp_send(
            # to = c("david.altare@waterboards.ca.gov", "waterdata@waterboards.ca.gov"),
            to = email_to,
            from = email_from,
            subject = subject,
            credentials = creds_file(credentials_file)
            # credentials = creds_key("outlook_key")
        )
    
    ### send email via sendmailR (for use on GIS scripting server) ----
    # sendmail(email_from,email_to,subject,body,control=list(smtpServer= "gwgate.waterboards.ca.gov"))
    
    print('sent automated email')
}



# delete old versions of dataset ------------------------------------------
tryCatch(
    {
        delete_old_versions <- TRUE
        filename_delete <- 'water_rights_list'
        if (delete_old_versions == TRUE) {
            files_list <- grep(pattern = paste0('^', filename_delete), 
                               x = list.files(file_save_location), 
                               value = TRUE) # get a list of all of the files of this type (including the new one) (NOTE: ^ means: starts with..)
            files_to_keep <- c(paste0(filename_delete, '_', Sys.Date() - seq(0,7), '.csv')) # keep the files from the previous 7 days
            files_list_old <- files_list[!(files_list %in% files_to_keep)] # exclude the new file from the list of files to be deleted
            if (length(files_list_old) > 0) {
                file.remove(paste0(file_save_location, files_list_old))
            }
        }
    },
    error = function(e) {
        error_message <- 'deleting old versions of files'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



# download source file and read data into R -------------------------------
## download file ----
tryCatch(
    {
        temp <- tempfile()
        download.file(url = file_link, 
                      destfile = temp, 
                      method = 'curl')
    },
    error = function(e) {
        error_message <- 'downloading source data file'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

## read data into R ----
tryCatch(
    {
        df_data <- read_csv(file = temp, 
                            col_types = cols(.default = col_character())) %>% #, quote = '') #%>% select(-X264)
            #type_convert() %>% 
            {.}
    },
    error = function(e) {
        error_message <- 'reading data into R'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

## check whether the data is valid ----
tryCatch(
    {
        if (nrow(df_data) == 0 | str_detect(string = names(df_data[1]), pattern = '<html>')) {
            error_message <- 'incomplete / invalid file download'
            fn_send_email(error_msg = error_message, 
                          error_msg_r = 'None')
            print(glue('Error: {error_message}'))
            stop()
        }
    },
    error = function(e) {
        error_message <- 'checking for valid data'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



# format data -------------------------------------------------------------
## clean field names / remove some fields ----
tryCatch(
    {
        # df_data <- clean_names(df_data)
        df_data_filter <- df_data %>% 
            select(-c(APPLICATION_NUMBER_PARTY, PWSS_ID, FEE_DUE, NUM_COMMENTS, 
                      NUM_ATTACHMENTS, LAST_UPDATE_DATE, PRIMARY_OWNER_ENTITY_TYPE_P, 
                      CURRENT_STATUS, APPL_ID, PERMIT_PERMIT_ID, LICENSE_LICENSE_ID))
    },
    error = function(e) {
        error_message <- 'formatting data (selecting fields and cleaning field names)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

# ensure all records are in UTF-8 format, convert if not ----
tryCatch(
    {
        df_data_filter <- df_data_filter %>%
            # map_df(~iconv(., to = 'UTF-8')) %>% # this is probably slower
            mutate(across(everything(),
                          ~iconv(., to = 'UTF-8'))) %>%
            {.}
    },
    error = function(e) {
        error_message <- 'formatting data (converting to UTF-8)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

## remove characters for quotes, tabs, returns, pipes, etc ----
tryCatch(
    {
        remove_characters <- c('\"|\t|\r|\n|\f|\v|\\|')
        df_data_filter <- df_data_filter %>%
            map_df(~str_replace_all(., remove_characters, ' '))
        #     ### check - delete this later
        #     tf <- str_detect(replace_na(df_data_filter$record_summary, 'NA'),
        #                     remove_characters)
        #     sum(tf)
        #     check_rows <- df_data_filter$record_summary[tf]
        #     check_rows[1] # view first one
        #     check_rows_fixed <- str_replace_all(check_rows, remove_characters, ' ')
        #     check_rows_fixed[1] # view first one
    },
    error = function(e) {
        error_message <- 'formatting data (removing special characters)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



## format date fields ----
### (convert dates into a timestamp field that can be read by the portal)
tryCatch(
    {
        # dplyr::glimpse(df_data_filter)
        fields_dates <- c('PRIORITY_DATE', 'RECEIPT_DATE', 'REJECTION_DATE', 
                          'APPLICATION_RECD_DATE', 'APPLICATION_ACCEPTANCE_DATE', 'EFFECTIVE_FROM_DATE', 
                          'EFFECTIVE_TO_DATE', 'EFFECTIVE_DATE', 
                          'PERMIT_ORIGINAL_ISSUE_DATE', 'COMPLETE_CONSTRUCTION_DATE', 'COMPLETE_APPLIC_WATER_DATE', 
                          'LICENSE_ORIGINAL_ISSUE_DATE', 'LICENSE_REQUESTED_DATE', 'INSPECTION_DATE', 
                          'REPORT_DATE', 'OFFER_SENT_DATE', 'ACCEPTED_OFFER_DATE', 
                          'DATE_RECEIVED', 'DATE_COMPLETED',
                          'ENF_CASE_START_DATE', 'ENF_CASE_CLOSURE_DATE')
        
        for (counter in seq(length(fields_dates))) {
            # convert the date field to ISO format
            dates_iso <- mdy(df_data_filter[[fields_dates[counter]]])
            # check NAs: sum(is.na(dates_iso))
            # Convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
            dates_iso <- as.character(dates_iso)
            # Check: sum(is.na(dates_iso))
            dates_iso[is.na(dates_iso)] <- ''
            # check NAs: sum(is.na(dates_iso))
            # Insert the revised date field back into the dataset
            df_data_filter[,fields_dates[counter]] <- dates_iso
        }
    }, 
    error = function(e) {
        error_message <- 'formatting date fields'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)


## format timestamp fields ----
### (convert dates into a timestamp field that can be read by the portal)
tryCatch(
    {
        # dplyr::glimpse(df_data_filter)
        fields_timestamp <- c('UPDATE_DATETIME', 'POD_LAST_UPDATE_DATE', 'PET_LAST_UPDATE_DATE')
        
        for (counter in seq(length(fields_timestamp))) {
            # convert the date field to ISO format
            dates_iso <- dmy_hms(df_data_filter[[fields_timestamp[counter]]])
            # check NAs: sum(is.na(dates_iso))
            # Convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
            dates_iso <- as.character(dates_iso)
            # Check: sum(is.na(dates_iso))
            dates_iso[is.na(dates_iso)] <- ''
            # check NAs: sum(is.na(dates_iso))
            # Insert the revised date field back into the dataset
            df_data_filter[,fields_timestamp[counter]] <- dates_iso
        }
    }, 
    error = function(e) {
        error_message <- 'formatting timestamp fields'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



## format numeric fields ----
### (ensure all records are compatible with numeric format)
tryCatch(
    {
        fields_numeric <- c('NUMBER_OF_PROTESTS', 'INI_REPORTED_DIV_AMOUNT', 'FACE_VALUE_AMOUNT', 
                            'FEE_RECEIVED', 'APPL_FEE_AMOUNT', 'APPL_FEE_AMT_RECD', 'MAX_DD_APPL', 
                            'MAX_DD_ANN', 'MAX_STORAGE', 'MAX_TAKEN_FROM_SOURCE', 'YEAR_DIVERSION_COMMENCED', 
                            'MAX_BENEFICIALLY_USED', 'QUANTITY_OF_WATER_DIVERTED', 'QUANTITY_MEASUREMENT_YEAR', 
                            'MAX_RATE_OF_DIVERSION', 'RECENT_WATER_USE_MIN', 'RECENT_WATER_USE_MAX', 
                            'DRILLED_WELL_YEAR', 'DEPTH_OF_WELL', 'COUNT_NPO_OR_OTHER', 'NUMBER_OF_RESIDENCES', 
                            'USE_POPULATION', 'USE_POPULATION_PEOPLE', 'ESTIMATED_USE_PER_PERSON', 
                            'USE_POPULATION_STOCK', 'AREA_FOR_INCI_IRRIGATION', 'USE_NET_ACREAGE', 
                            'USE_GROSS_ACREAGE', 'USE_DIRECT_DIV_ANNUAL_AMOUNT', 'USE_DIRECT_DIVERSION_RATE', 
                            'USE_STORAGE_AMOUNT', 'SEASON_DIRECT_DIV_RATE', 'SEASON_STORAGE_AMOUNT', 
                            'SEASON_DIRECT_DIV_AA', 'USE_COUNT', 'POD_NUMBER', 'DIRECT_DIV_AMOUNT', 
                            'DIRECT_DIVERSION_RATE', 'STORAGE_AMOUNT', 'DIVERSION_RATE_TO_OFF_STREAM', 
                            'POD_COUNT', 'SP_ZONE', 'NORTH_COORD', 'EAST_COORD', 'LATITUDE', 
                            'LONGITUDE', 'SECTION_NUMBER', 'TOWNSHIP_NUMBER', 'RANGE_NUMBER', 
                            'HUC_12_NUMBER', 'HUC_8_NUMBER', 'NUM_OF_PETITIONS', 'NUMBER_OF_ENFORCEMENT_CASE')
        
        # fields not converted to numeric but could be:
        # 'WR_WATER_RIGHT_ID', 'POD_ID', 'OBJECTID', 'POD_NUMBER_GIS', 'POD_ID_GIS'
        
        # convert to numeric
        for (counter in seq(length(fields_numeric))) {
            df_data_filter[,fields_numeric[counter]] <- as.numeric(df_data_filter[[fields_numeric[counter]]])
        }
    },
    error = function(e) {
        error_message <- 'formatting numeric fields'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

## Convert missing values in text fields to 'NA' ----
### (done to avoid converting to NaN when saving to csv)
### from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
tryCatch(
    {
        df_data_filter <- df_data_filter %>% 
            mutate_if(is.character, ~replace(., is.na(.), 'NA'))
        # mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))
    },
    error = function(e) {
        error_message <- 'formatting text fields'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



# write revised dataset to csv file ---------------------------------------
tryCatch(
    {
        out_file <- paste0(file_save_location, 
                           'water_rights_list_', 
                           Sys.Date(), 
                           '.csv')
        write_excel_csv(x = df_data_filter, 
                        file = out_file, 
                        na = 'NaN')
    },
    error = function(e) {
        fn_send_email(error_msg = 'writing output file')
        # tracker <<- 'Error: writing output file'
        print('Error: writing output file')
        stop()
    }
)



# write to open data portal -----------------------------------------------
tryCatch(
    {
        ckanr_setup(url = 'https://data.ca.gov/',
                    key = portal_key)
        # get resource info (just as a check)
        # ckan_resource_info <- resource_show(id = resourceID, as = 'table')
        file_upload <- resource_update(id = resourceID, 
                                       path = out_file)
    },
    error = function(e) {
        error_message <- 'uploading data to data.ca.gov portal'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

print('Completed Water Rights Data Upload Script')
