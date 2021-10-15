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
file_link <- 'https://intapps.waterboards.ca.gov/downloadFile/faces/flatFilesEwrims.xhtml?fileName=ewrims_flat_file.csv'

## define data portal resource ID
resourceID <- '151c067a-088b-42a2-b6ad-99d84b48fb36' # https://data.ca.gov/dataset/water-rights/resource/151c067a-088b-42a2-b6ad-99d84b48fb36

## get data portal API key
#### key is saved in the local environment (it's available on data.ca.gov by going to your user profile)
portal_key <- Sys.getenv('data_portal_key')
# portal_key <- '' # for GIS scripting server, enter key here

## define location where files will be saved
file_save_location <- 'C:\\David\\_CA_data_portal\\Water-Rights\\'
# file_save_location <- 'D:\\Data\\Scripts\\R\\water_rights_update\\' # for GIS scripting server

## enter the email address to send warning emails from
### NOTE - if sending from a personal email address, you'll have to update the credentials -- see below
email_from <- 'daltare.work@gmail.com' # 'david.altare@waterboards.ca.gov'
credentials_file <- 'gmail_creds' # this is the credentials file to be used (corresponds to the email_from address)
# email_from <- 'gisscripts-noreply@waterboards.ca.gov' # for GIS scripting server

## enter the email address (or addresses) to send warning emails to
email_to <- 'david.altare@waterboards.ca.gov' 
# email_to <- c('david.altare@waterboards.ca.gov', 'waterdata@waterboards.ca.gov') # for GIS scripting server



# setup automated email -----------------------------------------------
## create credentials file (only need to do this once, and only if sending from a personal email account) ----
### outlook credentials ----
# create_smtp_creds_file(file = 'outlook_creds', 
#                        user = 'david.altare@waterboards.ca.gov',
#                        provider = 'outlook'
#                        ) 
#
### gmail credentials ----
#### !!! NOTE - for gmail, you also have to enable 'less secure apps'  within your 
#### gmail account settings - see: https://github.com/rstudio/blastula/issues/228
# create_smtp_creds_file(file = 'gmail_creds', 
#                        user = 'daltare.work@gmail.com',
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
        download.file(url = file_link, destfile = temp, method = 'curl')
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
        df_data <- clean_names(df_data)
        df_data_filter <- df_data %>% 
            select(-c(application_number_party, pwss_id, fee_due, num_comments, 
                      num_attachments, last_update_date, primary_owner_entity_type_p, 
                      current_status, appl_id, permit_permit_id, license_license_id))
    },
    error = function(e) {
        error_message <- 'formatting data (selecting fields and cleaning field names)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

## ensure all records are in UTF-8 format, convert if not ----
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
        fields_dates <- c('priority_date', 'receipt_date', 'rejection_date', 
                          'application_recd_date', 'application_acceptance_date', 'effective_from_date',
                          'effective_to_date', 'effective_date', 
                          # 'update_datetime',
                          # 'pod_last_update_date',
                          'permit_original_issue_date', 'complete_construction_date',
                          'complete_applic_water_date', 'license_original_issue_date','license_requested_date',
                          'inspection_date', 'report_date', 'offer_sent_date', 
                          'accepted_offer_date', 'date_received', 'date_completed',
                          # 'pet_last_update_date', 
                          'enf_case_start_date', 'enf_case_closure_date')
        
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

## format numeric fields ----
### (ensure all records are compatible with numeric format)
tryCatch(
    {
        fields_numeric <- c('number_of_protests', 'ini_reported_div_amount',
                            'face_value_amount', 'fee_received', 'appl_fee_amount', 
                            'appl_fee_amt_recd', 'max_dd_appl', 'max_dd_ann', 
                            'max_storage', 'max_taken_from_source', 'year_diversion_commenced', 
                            'max_beneficially_used', 'quantity_of_water_diverted', 'quantity_measurement_year',
                            'max_rate_of_diversion', 'recent_water_use_min', 'recent_water_use_max',
                            'drilled_well_year', 'depth_of_well', 'count_npo_or_other', 
                            'number_of_residences', 'use_population', 'use_population_people',
                            'estimated_use_per_person', 'use_population_stock', 'area_for_inci_irrigation',
                            'use_net_acreage', 'use_gross_acreage', 'use_direct_div_annual_amount',
                            'use_direct_diversion_rate', 'use_storage_amount', 'season_direct_div_rate', 
                            'season_storage_amount', 'season_direct_div_aa', 'use_count',
                            'pod_number', 'direct_div_amount',
                            'direct_diversion_rate', 'storage_amount', 'diversion_rate_to_off_stream',
                            'pod_count',  
                            'sp_zone', 'north_coord',
                            'east_coord', 'latitude', 'longitude',
                            'section_number', 'township_number', 'range_number',
                            'huc_12_number', 'huc_8_number', 'num_of_petitions', 
                            'number_of_enforcement_case')
        
        # fields not converted to numeric but could be:
        # 'wr_water_right_id', 'pod_id', 'objectid', 'pod_number_gis', 'pod_id_gis', 
        
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
        out_file <- paste0(file_save_location, 'water_rights_list_', Sys.Date(), '.csv')
        write_csv(x = df_data_filter, file = out_file, na = 'NaN')
    },
    error = function(e) {
        fn_send_email(error_msg = 'writing output file')
        # tracker <<- 'Error: writing output file'
        print('Error: writing output file')
        stop()
    }
)



# write to open data portal -----------------------------------------------
# tryCatch(
#     {
#         ckanr_setup(url = 'https://data.ca.gov/',
#                     key = portal_key)
#         # get resource info (just as a check)
#         # ckan_resource_info <- resource_show(id = resourceID, as = 'table')
#         file_upload <- resource_update(id = resourceID, path = out_file)
#     },
#     error = function(e) {
#         error_message <- 'uploading data to data.ca.gov portal'
#         error_message_r <- capture.output(cat(as.character(e)))
#         fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
#         print(glue('Error: {error_message}'))
#         stop(e)
#     }
# )

print('Completed Water Rights Data Upload Script')