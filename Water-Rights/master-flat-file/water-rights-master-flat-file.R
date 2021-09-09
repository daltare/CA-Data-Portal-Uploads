# NOTE: To schedule this script to run automatically, go to 'Addins' and 'Schedule R scripts on...', then select 
# the file that calls this script ("C:\\David\\Open_Data_Project\\__CA_DataPortal\\_Call_Scripts\\Call_SurfWater_Script.R.R")
# and set the time/date option (make sure the date format is %m/%d/%Y)


# Load packages ----
library(ckanr) # this lets you work with the CKAN portal
library(tidyverse)
library(janitor)
library(lubridate)
library(blastula) # for sending automated email
library(glue)


# set up defaults ----
## define direct link to the data
file_link <- 'https://intapps.waterboards.ca.gov/downloadFile/faces/flatFilesEwrims.xhtml?fileName=ewrims_flat_file.csv'

## define data portal resource ID
resourceID <- '151c067a-088b-42a2-b6ad-99d84b48fb36' # https://data.ca.gov/dataset/water-rights/resource/151c067a-088b-42a2-b6ad-99d84b48fb36

## define location where files will be saved
file_save_location <- 'C:\\David\\_CA_data_portal\\Water-Rights\\'


# setup error handling ----
## tracker variable ----
# tracker <- 'OK'

## automated email ----
### create credentials file (only need to do this once) ----
# create_smtp_creds_file(file = 'outlook_creds', 
#                        user = 'david.altare@waterboards.ca.gov',
#                        provider = 'outlook'
#                        )   

### create email function ----
fn_send_email <- function(error_msg) {
    ### create components ----
    
    #### date/time ----
    date_time <- add_readable_time()
    
    #### body ----
    body <- glue(
                "Hi,
There was an error uploading the Water Rights Master Flat File data to the data.ca.gov portal on {Sys.Date()}.
                
The process failed at this step: {error_msg}
                
Here's the link to the dataset on the data portal: https://data.ca.gov/dataset/water-rights/resource/151c067a-088b-42a2-b6ad-99d84b48fb36
                
Here's the link to the flat file with the source data: https://intapps.waterboards.ca.gov/downloadFile/faces/flatFilesEwrims.xhtml  (File Name = ewrims_flat_file.csv)"                
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
            # to = c("david.altare@waterboards.ca.gov", "waterdata@waterboards.ca.gov"),
            to = "david.altare@waterboards.ca.gov",
            from = "david.altare@waterboards.ca.gov",
            subject = subject,
            credentials = creds_file("outlook_creds")
            # credentials = creds_key("outlook_key")
        )
    
    ### send email via sendmailR (for use on GIS scripting server) ----
    # from <- "gisscripts-noreply@waterboards.ca.gov"
    # to <- c("david.altare@waterboards.ca.gov", "waterdata@waterboards.ca.gov")
    # sendmail(from,to,subject,body,control=list(smtpServer= "gwgate.waterboards.ca.gov"))
    
    print('sent automated email')
}


# delete old versions of dataset ----
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
    
    
# download the files and read data into R ----
temp <- tempfile()

## download file ----
tryCatch(
    download.file(url = file_link, destfile = temp, method = 'curl'),
    error = function(e) {
        fn_send_email(error_msg = 'downloading and reading data (file download)')
        # tracker <<- 'Error: file download'
        print('Error: file download')
        stop()
    }
)

## read data into R ----
tryCatch(
    df_data <- read_csv(file = temp, 
                        col_types = cols(.default = col_character())) %>% #, quote = '') #%>% select(-X264)
        type_convert(),
    error = function(e) {
        fn_send_email(error_msg = 'downloading and reading data (reading data)')
        # tracker <<- 'Error: reading data into R'
        print('Error: reading data into R')
        stop()
    }
)

## check whether the data is valid ----
if (nrow(df_data) == 0 | str_detect(string = names(df_data[1]), pattern = '<html>')) {
    fn_send_email(error_msg = 'downloading and reading data (incomplete / invalid file download)')
    print('Error: incomplete / invalid file download')
    stop()
}

# format data ----
## clean up the names ----
df_data <- clean_names(df_data)

## remove some fields prior to publication ----
tryCatch(
    df_data_filter <- df_data %>% 
        select(-c(application_number_party, pwss_id, fee_due, num_comments, 
                  num_attachments, last_update_date, primary_owner_entity_type_p, 
                  current_status, appl_id, permit_permit_id, license_license_id)),
    error = function(e) {
        fn_send_email(error_msg = 'formatting data (selecting fields)')
        # tracker <<- 'Error: selecting fields'
        print('Error: formatting data (selecting fields)')
        stop()
    }
)



    
## format date fields ----
### (convert dates into a timestamp field that can be read by the portal)
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
tryCatch(
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
    }, 
    error = function(e) {
        fn_send_email(error_msg = 'formatting data (date fields)')
        # tracker <<- 'Error: formatting date fields'
        print('Error: formatting date fields')
        stop()
    }
)

## format numeric fields ----
### (ensure all records are compatible with numeric format)
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
                    'number_of_enforcement_case'
)

# fields not converted to numeric but could be:
# 'wr_water_right_id', 'pod_id', 'objectid', 'pod_number_gis', 'pod_id_gis', 
# convert to numeric
tryCatch(
    for (counter in seq(length(fields_numeric))) {
        df_data_filter[,fields_numeric[counter]] <- as.numeric(df_data_filter[[fields_numeric[counter]]])
    },
    error = function(e) {
        fn_send_email(error_msg = 'formatting data (numeric fields)')
        # tracker <<- 'Error: formatting numeric fields'
        print('Error: formatting numeric fields')
        stop()
    }
)

## Convert missing values in text fields to 'NA' ----
### (done to avoid converting to NaN when saving to csv) !!!!!!!!!!!
### from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
df_data_filter <- df_data_filter %>% 
    mutate_if(is.character, ~replace(., is.na(.), 'NA'))
# mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))


# write revised dataset to csv ----
out_file <- paste0(file_save_location, 'water_rights_list_', Sys.Date(), '.csv')
tryCatch(
    write_csv(x = df_data_filter, file = out_file, na = 'NaN'),
    error = function(e) {
        fn_send_email(error_msg = 'writing output file')
        # tracker <<- 'Error: writing output file'
        print('Error: writing output file')
        stop()
    }
)
    
    
# write to the open data portal ----
## get portal key ----
### the data portal API key is saved in the local environment (it's available on data.ca.gov by going to your user profile)
tryCatch(
    portal_key <- Sys.getenv('data_portal_key'),
    error = function(e) {
        fn_send_email(error_msg = 'sending data to portal (retrieving portal key)')
        # tracker <<- 'Error: retrieving portal key'
        print('Error: retrieving portal key')
        stop()
    }
)

if (portal_key == '') {
    fn_send_email(error_msg = 'sending data to portal (retrieving portal key)')
    print('Error: retrieving portal key')
    stop()
}

## set ckanr defaults ----
tryCatch(
    ckanr_setup(url = 'https://data.ca.gov/', 
                key = portal_key),
    error = function(e) {
        fn_send_email(error_msg = 'sending data to portal (setting ckanr defaults)')
        # tracker <<- 'Error: setting ckanr defaults'
        print('Error: setting ckanr defaults')
        stop()
    }
)

# get resource info (just as a check)
# ckan_resource_info <- resource_show(id = resourceID, as = 'table')

## send to portal ----
tryCatch(
    file_upload <- ckanr::resource_update(id = resourceID, path = out_file),
    error = function(e) {
        fn_send_email(error_msg = 'sending data to portal (uploading data file)')
        # tracker <<- 'Error: uploading data file to portal'
        print('Error: uploading data file to portal')
        stop()
    }
)


# status
# print(glue('Process Completed (Status - {tracker})'))
        