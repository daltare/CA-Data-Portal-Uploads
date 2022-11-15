
# load packages -----------------------------------------------------------
library(ckanr) # this lets you work with the CKAN portal
library(tidyverse)
library(janitor)
library(lubridate)
library(glue)
library(blastula)
library(sendmailR)



# user inputs -------------------------------------------------------------
## define direct link to the data
file_link <- 'https://intapps.waterboards.ca.gov/downloadFile/faces/flatFilesCiwqs.xhtml?fileName=reg_meas_export.txt'

## define location where files will be saved
file_save_location <- 'C:\\David\\_CA_data_portal\\Surface-Water-Datasets\\'

## define data portal resource ID
resourceID <- 'c16335af-f2dc-41e6-a429-f19edba5b957' # https://data.ca.gov/dataset/surface-water-water-quality-regulated-facility-information/resource/c16335af-f2dc-41e6-a429-f19edba5b957

## get data portal API key ----
#### key is saved in the local environment (it's available on data.ca.gov by going to your user profile)
portal_key <- Sys.getenv('data_portal_key')

## define data file name
filename_dataset <- 'reg_meas_export_CAFO_'

## delete old versions of the dataset? (the ones saved locally) - TRUE or FALSE
delete_old_versions <- TRUE

## enter the email address to send warning emails from
### NOTE - if sending from a personal email address, you'll have to update the credentials -- see below
email_from <- 'daltare.swrcb@gmail.com' # 'david.altare@waterboards.ca.gov' # "gisscripts-noreply@waterboards.ca.gov"
credentials_file <- 'gmail_creds' # this is the credentials file to be used (corresponds to the email_from address)
# email_from <- "gisscripts-noreply@waterboards.ca.gov" # for GIS scripting server

## enter the email address (or addresses) to send warning emails to
email_to <- 'david.altare@waterboards.ca.gov' 
# email_to <- c('david.altare@waterboards.ca.gov', 'waterdata@waterboards.ca.gov') # for GIS scripting server



# setup automated email ---------------------------------------------------
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
There was an error uploading the Confined Animal Facilities regulatory data (from CIWQS) to the data.ca.gov portal on {Sys.Date()}.
                
------
                
The process failed at this step: *{error_msg}*

Here's the error message from R: *{glue_collapse(error_msg_r, sep = ' | ')}*

------
                
Here's the link to the dataset on the data portal: https://data.ca.gov/dataset/surface-water-water-quality-regulated-facility-information/resource/c16335af-f2dc-41e6-a429-f19edba5b957
                
Here's the link to the flat file with the source data: https://intapps.waterboards.ca.gov/downloadFile/faces/flatFilesCiwqs.xhtml  (Export Type = Regulatory Measures)"                
            )
    
    #### footer ----
    footer <- glue("Email sent on {date_time}.")
    
    #### subject ----
    subject <- "Data Portal Upload Error (Confined Animal Facilities Regulatory Data)"
    
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
    # sendmail(email_from, email_to, subject, body, control=list(smtpServer= "")) # insert smtpServer name before use
    
    print('sent automated email')
}



# delete old versions of dataset --------------------------------------
tryCatch(
    if (delete_old_versions == TRUE) {
        files_list <- grep(pattern = paste0('^', filename_dataset), x = list.files(file_save_location), value = TRUE) # get a list of all of the files of this type (including the new one) (NOTE: ^ means: starts with..)
        # files_list_old <- files_list[files_list != paste0(filename, '_', Sys.Date(), '_Raw.txt')] # exclude the new file from the list of files to be deleted
        files_to_keep <- c(paste0(filename_dataset, Sys.Date() - seq(0,7), '.csv')) # keep the files from the previous 7 days
        files_to_keep <- files_to_keep[files_to_keep %in% files_list]
        files_list_old <- files_list[!(files_list %in% files_to_keep)] # exclude the new file from the list of files to be deleted
        if (length(files_list_old) > 0 & length(files_to_keep) > 0) {
            file.remove(paste0(file_save_location, files_list_old))
        }
    },
    error = function(e) {
        error_message <- 'deleting old versions of dataset'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



# download flat file ------------------------------------------------------
tryCatch(
    {
        temp <- tempfile()
        download.file(url = file_link, destfile = temp, method = 'curl')
    },
    error = function(e) {
        error_message <- 'downloading flat file data'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



# read data into R --------------------------------------------------------
tryCatch(
    {
        df_data <- readr::read_tsv(file = temp, 
                                   col_types = cols(.default = col_character()), 
                                   quote = '') %>% 
            type_convert() %>% 
            clean_names() %>% 
            select(-starts_with(c('X', 'x'))) %>% 
            {.}
    },
    error = function(e) {
        error_message <- 'reading flat file data into R'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



# format data -------------------------------------------------------------
## filter for relevant data ----
#### select the rows where 'PROGRAM CATEGORY' is 'ANIMALWASTE', 'STATUS' is 'Active', 
#### and 'REG MEASURE TYPE' is not '13267 Letter (Non-Enforcement)' or 'Letter'
tryCatch(
    {
        df_data_filter <- df_data %>% 
            filter(program_category == 'ANIMALWASTE',
                   status == 'Active' | status == 'Historical',
                   reg_measure_type != '13267 Letter (Non-Enforcement)',
                   reg_measure_type != 'Letter')
    },
    error = function(e) {
        error_message <- 'filtering flat file data'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

## select just relevant fields ----
tryCatch(
    {
        df_data_filter <- df_data_filter %>% 
            select("reg_measure_id","reg_measure_type","reg_measure_title",
                   "reg_measure_description","order_number","npdes_number_ca_number",
                   "program","program_category","wdid",
                   "region","status","effective_date",
                   "expiration_review_date","termination_date","adoption_date",
                   "individual_general","fee_code","facility_waste_type",
                   "facility_waste_type_2","number_of_amendments","most_recent_amendment_number",
                   "most_recent_amendment_date","most_recent_amendment_comments","rescission_number",
                   "rescission_date","rescission_comments","facility_id",
                   "facility_region","facility_name","place_type",
                   "place_address","place_city","place_zip",
                   "place_county","latitude_decimal_degrees","longitude_decimal_degrees",
                   "approved_cnty_reg_prog","cafo_subtype","cafo_type",
                   "onsite","cafo_population","quality_assurance",
                   "sic_code_1","sic_desc_1","animal_equivalent_units_aeu",
                   "agency_name","agency_type")
    },
    error = function(e) {
        error_message <- 'selecting fields'
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
#### check dataset for portal compatibility and adjust as needed (convert dates into a timestamp field that can be read by the portal)
# glimpse(df_data_filter)
tryCatch(
    {
        ### define date fields ----
        fields_dates <- c('effective_date', 'expiration_review_date', 'termination_date', 
                          'adoption_date', 'rescission_date')
        ### convert ----
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
#### ensure all records are compatible with numeric format 
tryCatch(
    {
        ### define numeric fields ----
        fields_numeric <- c('number_of_amendments', 'latitude_decimal_degrees', 'longitude_decimal_degrees',
                            'cafo_population', 'animal_equivalent_units_aeu')
        ### convert ----
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
    
## format text fields ----
#### Convert missing values in text fields to 'NA' (to avoid converting to NaN)
#### from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
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
        out_file <- paste0(file_save_location, filename_dataset, Sys.Date(), '.csv')
        write_csv(x = df_data_filter, file = out_file, na = 'NaN')
    },
    error = function(e) {
        error_message <- 'writing output csv file'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

    

# write to open data portal -----------------------------------------------
tryCatch(
    {
        ## set ckan defaults ----
        ckanr_setup(url = 'https://data.ca.gov/', key = portal_key)
        
        ## get resource info (just as a check)
        # ckan_resource_info <- resource_show(id = resourceID, as = 'table')
        
        ## write to portal ----
        file_upload <- ckanr::resource_update(id = resourceID, path = out_file)
    },
    error = function(e) {
        error_message <- 'writing dataset to data.ca.gov portal'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)
