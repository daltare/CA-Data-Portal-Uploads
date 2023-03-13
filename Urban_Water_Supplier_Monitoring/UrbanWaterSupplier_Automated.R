# NOTE: To schedule this script to run automatically, go to 'Addins' and 'Schedule R scripts on...', then select 
# the file that calls this script ("C:\\David\\Open_Data_Project\\__CA_DataPortal\\_Call_Scripts\\Call_UrbanSupplierConservation.R")
# and set the time/date option (make sure the date format is %m/%d/%Y)



# load packages -----------------------------------------------------------
library(tidyverse)
library(readxl)
library(reticulate) # this lets you import packages/functions/etc. from python into R
library(lubridate) # for working with dates
library(ckanr)
library(janitor)
library(glue)
library(blastula)
library(sendmailR)



# 1 - user inputs -------------------------------------------------------------
## homepage of the waterboard's "Water Conservation Portal"
url_base <- 'https://www.waterboards.ca.gov/water_issues/programs/conservation_portal'

## webpage for the waterboard's "Water Conservation and Production Reports"  that contains the link to the dataset
url_conservation_portal <- glue('{url_base}/conservation_reporting.html')

## base url where the data file is stored (path to specific dataset is appended to this base url)
url_resources <- glue('{url_base}/docs') # the actual location where the conservation datasets are stored

## url where the data is retrieved from
# base_url <- 'https://www.waterboards.ca.gov/water_issues/programs/conservation_portal/docs/' # the location where the conservation datasets are posted

## portal resource ID
ckan_resource_id <- '0c231d4c-1ea7-43c5-a041-a3a6b02bac5e' # https://data.ca.gov/dataset/drinking-water-public-water-system-operations-monthly-water-production-and-conservation-information/resource/0c231d4c-1ea7-43c5-a041-a3a6b02bac5e

## get data portal API key
#### key is saved in the local environment (it's available on data.ca.gov by going to your user profile)
portal_key <- Sys.getenv('data_portal_key')

## define location where files will be saved
file_save_location <- 'C:\\David\\_CA_data_portal\\Urban_Water_Supplier_Monitoring'

## enter the maximum number of days between portal updates before triggering a warning email to be sent
max_update_lag <- 60 # number of days

## enter the email address to send warning emails from
### NOTE - if sending from a personal email address, you'll have to update the credentials -- see below
email_from <- 'daltare.swrcb@gmail.com' # 'david.altare@waterboards.ca.gov' # "gisscripts-noreply@waterboards.ca.gov"
credentials_file <- 'gmail_creds' # this is the credentials file to be used (corresponds to the email_from address)
# email_from <- 'gisscripts-noreply@waterboards.ca.gov' # for GIS scripting server

## enter the email address (or addresses) to send warning emails to
email_to <- 'david.altare@waterboards.ca.gov' 
# email_to <- c('david.altare@waterboards.ca.gov', 'waterdata@waterboards.ca.gov') # for GIS scripting server



# 2 - setup automated email -----------------------------------------------
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
        
There was an error uploading the Drinking Water Production & Conservation data to the data.ca.gov portal on {Sys.Date()}.

------
                
The process failed at this step: *{error_msg}*

Here's the error message from R: *{glue_collapse(error_msg_r, sep = ' | ')}*

------
                
Here's the link to the dataset on the data portal: https://data.ca.gov/dataset/drinking-water-public-water-system-operations-monthly-water-production-and-conservation-information
                
Here's the link to the website with the source data (see the link labeled \"Raw Dataset\"): https://www.waterboards.ca.gov/water_issues/programs/conservation_portal/conservation_reporting.html"                
    )
    
    #### footer ----
    footer <- glue("Email sent on {date_time}.")
    
    #### subject ----
    subject <- "Data Portal Upload Error - Drinking Water Production & Conservation Data"
    
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
    # sendmail(email_from,email_to,subject,body,control=list(smtpServer= ""))
    
    print('sent automated email')
}



# 3 - check when data portal was last updated ---------------------------------
tryCatch(
    {
        ## set ckan defaults ----
        ckanr_setup(url = 'https://data.ca.gov/', key = portal_key)
        
        ## get resource info (just as a check)
        ckan_resource_info <- resource_show(id = ckan_resource_id, as = 'table')
        
        ## get date last modified ----
        last_updated <- as.Date(ckan_resource_info$last_modified)
        update_lag <- as.numeric(Sys.Date() - last_updated) # number of days
        max_update_lag_exceeded <- update_lag >= max_update_lag 
        
        ## get other information about the resource currently on the data portal
        ckan_resource_file <- str_split(string = ckan_resource_info$url, pattern = '/')[[1]]
        ckan_resource_file <- ckan_resource_file[length(ckan_resource_file)]
        
    },
    error = function(e) {
        error_message <- 'checking how long since last portal update (NOTE: portal was last updated {update_lag} days ago)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)




# 4 - get link to source dataset ----------------------------------------------       

tryCatch(
    {
        ### METHOD 1 --------------------------------------------------------
        ### get the link from the main webpage
        
        ## read the conservation portal webpage (raw html)
        reports_page <- readLines(url_conservation_portal)
        
        ## cut out everything after the 'Archived Monthly Report' header
        # reports_page <- reports_page[1:grep('Archived Monthly Report', reports_page)[1]] 
        
        ## extract the lines that contain '.xlsx' and some form of 'uw supplier data'
        condition_1 <- str_detect(string = reports_page, 
                                  pattern = '.xlsx')
        
        condition_2 <- str_detect(string = str_replace_all(reports_page, '_|-', ''), # remove all '_' and '-' before searching for the 'uwsupplierdata' string
                                  pattern =  'uwsupplierdata')
        line_report <- reports_page[condition_1 & condition_2][1] # should only be one, but if not this will return the first/top one on the page
        
        ## extract the file name / path from the line with most recent date (and clean any extraneous information)
        file_path <- str_extract(string = line_report, 
                                 pattern = '<a href=(.+).xlsx') # the (.+) part is a wildcard
        file_path <- str_remove(string = file_path, 
                                pattern = '<a href=\"')
        file_path <- str_remove(string = file_path, 
                                pattern = 'docs/')
        file_path <- str_remove(string = file_path, 
                                pattern = 'https://www.waterboards.ca.gov/water_issues/programs/conservation_portal/')
        
        ## construct the url for the file
        file_url <-  file.path(glue('{url_resources}/{file_path}'))
        
        status <- 'File exists'
        file_name <- basename(file_path)
        
        ### METHOD 2 --------------------------------------------------------
        ### find the most recent file with the supplier dataset on the page where datsets are stored
        
        # # get the url for the reports page (if not found for current year, try last year)
        # tryCatch(
        #     {
        #         reports_url <- glue('{base_url}{year(Sys.Date())}_reports/')
        #         reports_page <- readLines(reports_url)
        #     },
        #     error = function(e) {
        #         reports_url <<- glue('{base_url}{year(Sys.Date())-1}_reports/') # have to use <<- to return the value to the global environment
        #         reports_page <<- readLines(reports_url) # have to use <<- to return the value to the global environment
        #     }
        # )
        # 
        # # extract the lines that contain '.xlsx' and some form of 'uw supplier data'
        # condition_1 <- str_detect(string = reports_page, 
        #                           pattern = '.xlsx')
        # 
        # condition_2 <- str_detect(string = str_replace_all(reports_page, '_|-', ''), # remove all '_' and '-' before searching for the 'uwsupplierdata' string
        #                           pattern =  'uwsupplierdata')
        # 
        # lines_reports <- reports_page[condition_1 & condition_2]
        # 
        # # extract dates from the selected lines
        # lines_dates <- str_extract(string = lines_reports, 
        #                            pattern = '\\d+-\\d+-\\d+')
        # upload_dates <- ymd(lines_dates)
        # most_recent <- max(upload_dates)
        # 
        # # get the line with the most recent date
        # line_most_recent <- lines_reports[str_detect(string = lines_reports, 
        #                                              pattern = as.character(most_recent))]
        # 
        # # extract the file name from the line with most recent date
        # file_name <- str_extract(string = line_most_recent, 
        #                          pattern = '<a href=(.+).xlsx') # the (.+) part is a wildcard
        # file_name <- str_remove(string = file_name, 
        #                         pattern = '<a href=\"')
        # 
        # # get the url to the most recent file
        # file_url <-  file.path(glue('{reports_url}{file_name}'))
        # 
        # status <- 'File exists'
        
        ### OLD METHOD ---------------------------------------------------------
        ## This loop cycles through each day of the current month until it finds a file posted in the current month.
        ## It assumes that the file is formated in a specific way (e.g., as 'YYYYmmm/uw_supplier_dataMMDDYY.xlsx', 
        ## so for August 2017, it's: '2017aug/uw_supplier_data080117.xlsx'), where the base URL is: 
        ## 'http://www.waterboards.ca.gov/water_issues/programs/conservation_portal/docs/'.
        # status <- 'File does not exist'
        # i <- 1
        # # Try various versions of the link, and check to see if the file exists
        # while((status == 'File does not exist') & (i < 32)) {
        #     # link version 1
        #     {
        #         test_link <- paste0(base_url, year(Sys.Date()), tolower(month.abb[month(Sys.Date())]), # build the link for a given date
        #                             '/uw_supplier_data', sprintf('%02d',month(Sys.Date())), sprintf('%02d',i), year(Sys.Date())-2000, '.xlsx')
        #         result <- suppressWarnings(tryCatch(readLines(con = test_link, n = 10), # check to see if a file with the given date exists
        #                                             error=function(e) return("Error")))
        #         if(result[1] != 'Error' & result[1]!= '<!doctype html>') {status <- 'File exists'}
        #     }
        #     # link version 2
        #     if (status == 'File does not exist') {
        #         test_link <- paste0(base_url, year(Sys.Date()), '_reports', # build the link for a given date
        #                             '/uw_supplier_data', sprintf('%02d',month(Sys.Date())), sprintf('%02d',i), year(Sys.Date())-2000, '.xlsx')
        #         result <- suppressWarnings(tryCatch(readLines(con = test_link, n = 10), # check to see if a file with the given date exists
        #                                             error=function(e) return("Error")))
        #         if(result[1] != 'Error' & result[1]!= '<!doctype html>') {status <- 'File exists'}
        #     }
        #     # link version 3 - sometimes the month name uses 4 characters instead of 3 - e.g. July 2018 - if the above didn't work, rebuild the link with the first 4 letters and try that
        #     if (status == 'File does not exist') {
        #         test_link <- paste0(base_url, year(Sys.Date()), tolower(substr(month.name[month(Sys.Date())],1,4)), # build the link for a given date
        #                             '/uw_supplier_data', sprintf('%02d',month(Sys.Date())), sprintf('%02d',i), year(Sys.Date())-2000, '.xlsx')
        #         result <- suppressWarnings(tryCatch(readLines(con = test_link, n = 10), # check to see if a file with the given date exists
        #                                             error=function(e) return("Error")))
        #         if(result[1] != 'Error' & result[1]!= '<!doctype html>') {status <- 'File exists'}
        #     }
        #     # link version 4 - sometimes the month name uses 4 characters instead of 3 - e.g. July 2018 - if the above didn't work, rebuild the link with the first 4 letters and try that
        #     if (status == 'File does not exist') {
        #         test_link <- paste0(base_url, year(Sys.Date()), '_reports', # build the link for a given date
        #                             '/uw_supplier_data', sprintf('%02d',month(Sys.Date())), sprintf('%02d',i), year(Sys.Date())-2000, '.xlsx')
        #         result <- suppressWarnings(tryCatch(readLines(con = test_link, n = 10), # check to see if a file with the given date exists
        #                                             error=function(e) return("Error")))
        #     }
        #     #  link version 5 - try again with an underscore before the date
        #     if (status == 'File does not exist') {
        #         test_link <- paste0(base_url, year(Sys.Date()), tolower(month.abb[month(Sys.Date())]), # build the link for a given date
        #                             '/uw_supplier_data_', sprintf('%02d',month(Sys.Date())), sprintf('%02d',i), year(Sys.Date())-2000, '.xlsx')
        #         result <- suppressWarnings(tryCatch(readLines(con = test_link, n = 10), # check to see if a file with the given date exists
        #                                             error=function(e) return("Error")))
        #         if(result[1] != 'Error' & result[1]!= '<!doctype html>') {status <- 'File exists'}
        #     }
        #     #  link version 6 - try again with an underscore before the date
        #     if (status == 'File does not exist') {
        #         test_link <- paste0(base_url, year(Sys.Date()), '_reports', # build the link for a given date
        #                             '/uw_supplier_data_', sprintf('%02d',month(Sys.Date())), sprintf('%02d',i), year(Sys.Date())-2000, '.xlsx')
        #         result <- suppressWarnings(tryCatch(readLines(con = test_link, n = 10), # check to see if a file with the given date exists
        #                                             error=function(e) return("Error")))
        #         if(result[1] != 'Error' & result[1]!= '<!doctype html>') {status <- 'File exists'}
        #     }
        #     if(status == 'File does not exist') {i <- i + 1} # increment i if the status is still the same
        #     if(i > 31) {break} # just to make sure it doesn't go into an endless loop, stops if it goes beyond day 31 in the month
        # }
        # # print(paste0('Status: ', status)) # just a check, not needed
    },
    error = function(e) {
        error_message <- glue('getting source file link (NOTE: portal was last updated {update_lag} days ago)')
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



# 5 - download source file ----------------------------------------------------
tryCatch(
    {
        if(status == 'File exists') {
            dest_filename <- file_name
            test_link <- file_url
            # dest_filename <- paste0('uw_supplier_data', sprintf('%02d',month(Sys.Date())), sprintf('%02d',i), 
            #                         year(Sys.Date())-2000, '.xlsx')
            # check to see if the downloaded data is the same as the existing data on the CA portal - if so, no update needed
            check_data <- identical(strsplit(ckan_resource_file, '.csv')[[1]], 
                                    strsplit(dest_filename, '.xlsx')[[1]])
            if(check_data == FALSE) { # only do this if there is new data that hasn't already been uploaded to the CA data portal
                directory_name <- paste0(year(Sys.Date()), '-', sprintf('%02d',month(Sys.Date())))
                dir.create(paste0(file_save_location, '\\', directory_name), showWarnings = FALSE)
                download.file(url = test_link, 
                              destfile = paste0(file_save_location, '\\', directory_name, '\\', dest_filename), 
                              method = 'curl')
                # print('File downloaded') # just a check, not needed
            }
        } else {
            check_data <-  TRUE
        }
    },
    error = function(e) {
        error_message <- glue('downloading source file (NOTE: portal was last updated {update_lag} days ago)')
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



# 6 - format data for portal --------------------------------------------------
if(check_data == FALSE) { # only do this if there is new data that hasn't already been uploaded to the CA data portal
    
    ## read in the new data to R ----
    tryCatch(
        {
            dataset <- read_excel(paste0(file_save_location, '\\', directory_name, '\\', dest_filename), guess_max = 50000)
            dataset <- as.data.frame(dataset)
            dataset_original <- dataset # create a copy of the original for comparison
        },
        error = function(e) {
            error_message <- glue('reading data into R (NOTE: portal was last updated {update_lag} days ago)')
            error_message_r <- capture.output(cat(as.character(e)))
            fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
            print(glue('Error: {error_message}'))
            stop(e)
        }
    )
    
    ## ensure all records are in UTF-8 format, convert if not ----
    tryCatch(
        {
            dataset <- dataset %>%
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
            dataset <- dataset %>%
                map_df(~str_replace_all(., remove_characters, ' '))
            #     ### check - delete this later
            #     tf <- str_detect(replace_na(dataset$record_summary, 'NA'),
            #                     remove_characters)
            #     sum(tf)
            #     check_rows <- dataset$record_summary[tf]
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
    
    
    ## clean field names and codes ----
    tryCatch(
        {
            # clean names
            dataset <- dataset %>% clean_names()
            
            # Replace various "Not Available" codes with NAs
            dataset <- dataset %>% mutate_if(is.character, list(~case_when(. == 'N/A' ~ NA_character_, 
                                                                           . == 'NA' ~ NA_character_,
                                                                           . == 'na' ~ NA_character_,
                                                                           . == 'n/a' ~ NA_character_,
                                                                           . == 'not avail.' ~ NA_character_,
                                                                           . == 'uk' ~ NA_character_,
                                                                           . == 'Null' ~ NA_character_,
                                                                           # . == 'No' ~ NA_character_,
                                                                           TRUE ~ .))) 
        },
        error = function(e) {
            error_message <- glue('cleaning field names and codes (NOTE: portal was last updated {update_lag} days ago)')
            error_message_r <- capture.output(cat(as.character(e)))
            fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
            print(glue('Error: {error_message}'))
            stop(e)
        }
    )
    
    ## numeric fields ----
    tryCatch(
        {
            # Convert columns that should be numeric from character to numeric (for compatibility with the data portal)
            dataset <- dataset %>% 
                mutate(total_population_served = as.numeric(total_population_served),
                       reported_preliminary_total_potable_water_production = as.numeric(reported_preliminary_total_potable_water_production),
                       reported_final_total_potable_water_production = as.numeric(reported_final_total_potable_water_production),
                       preliminary_percent_residential_use = as.numeric(preliminary_percent_residential_use),
                       final_percent_residential_use = as.numeric(final_percent_residential_use),
                       reported_preliminary_commercial_agricultural_water = as.numeric(reported_preliminary_commercial_agricultural_water),
                       reported_final_commercial_agricultural_water = as.numeric(reported_final_commercial_agricultural_water),
                       reported_preliminary_commercial_industrial_and_institutional_water = as.numeric(reported_preliminary_commercial_industrial_and_institutional_water),
                       reported_final_commercial_industrial_and_institutional_water = as.numeric(reported_final_commercial_industrial_and_institutional_water),
                       calculated_total_potable_water_production_gallons_ag_excluded = as.numeric(calculated_total_potable_water_production_gallons_ag_excluded),
                       calculated_total_potable_water_production_gallons_2013_ag_excluded = as.numeric(calculated_total_potable_water_production_gallons_2013_ag_excluded),
                       calculated_commercial_agricultural_water_gallons = as.numeric(calculated_commercial_agricultural_water_gallons),
                       calculated_commercial_agricultural_water_gallons_2013 = as.numeric(calculated_commercial_agricultural_water_gallons_2013),
                       calculated_r_gpcd = as.numeric(calculated_r_gpcd))
            # use to check a field for non-numeric values
            # field_values <- dataset$reported_final_commercial_industrial_and_institutional_water
            # field_values_numeric <- as.numeric(field_values)
            # field_values[!is.na(field_values) & is.na(field_values_numeric)]
        },
        error = function(e) {
            error_message <- glue('formatting numeric fields (NOTE: portal was last updated {update_lag} days ago)')
            error_message_r <- capture.output(cat(as.character(e)))
            fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
            print(glue('Error: {error_message}'))
            stop(e)
        }
    )
    
    ## character fields ----
    tryCatch(
        {
            # replace blanks with NAs in character fields (use NaN when writing to csv to take care of missing values in numeric fields, to work with requirements of the CA data portal for numeric values)
            # tf <- is.na(dataset)
            # dataset[tf] <- 'NA'
            dataset <- dataset %>% 
                mutate_if(is.character, ~replace(., is.na(.), 'NA'))
            # mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))
        },
        error = function(e) {
            error_message <- glue('formatting character fields (NOTE: portal was last updated {update_lag} days ago)')
            error_message_r <- capture.output(cat(as.character(e)))
            fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
            print(glue('Error: {error_message}'))
            stop(e)
        }
    )
    
    
    ## date fields ----
    tryCatch(
        {
            # convert the Reporting_Month field into a date 
            # dataset$Reporting_Month <- as.Date(dataset$Reporting_Month, origin = "1899-12-30")
            dataset$reporting_month <- suppressWarnings(tryCatch(as.Date(dataset$reporting_month, origin = "1899-12-30"), # check to see if a file with the given date exists
                                                                 error=function(e) return(lubridate::myd(paste0(dataset$reporting_month,'-15')))))
            # if there are records in this field that can't be converted to Date format, convert the NAs to '' (empty text string) - needed to comply with requirements of CA data portal
            sum(is.na(dataset$reporting_month))
            dataset$reporting_month <- as.character(dataset$reporting_month)
            dataset$reporting_month[is.na(dataset$reporting_month)] <- ''
            
            ## add a field that can be read as a timestamp - Not needed if the Reporting_Month field will be set as timestamp type on the data portal
            #     # first check for Reporting_Month records that can't be recognized as a timestamp, and convert them into NAs in the new field
            #         tf_date <- is.na(ymd(dataset$Reporting_Month))
            #         dataset <- dataset %>% mutate(Reporting_Month_timestamp = Reporting_Month)
            #         dataset$Reporting_Month_timestamp[tf_date] <- NA
            #     # create the timestamps
            #         dataset <- dataset %>% mutate(Reporting_Month_timestamp = case_when(is.na(Reporting_Month) ~ '',
            #                                                                             TRUE ~ paste0(Reporting_Month, ' 00:00:00')))
            
        },
        error = function(e) {
            error_message <- glue('formatting date fields (NOTE: portal was last updated {update_lag} days ago)')
            error_message_r <- capture.output(cat(as.character(e)))
            fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
            print(glue('Error: {error_message}'))
            stop(e)
        }
    )
    
    ## write output files to csv ----
    tryCatch(
        {
            # Write out the formatted file as a CSV
            output_path <- paste0(file_save_location, '\\', directory_name, '\\', strsplit(dest_filename, '.xlsx')[[1]], '.csv')
            write.csv(dataset, file = output_path, row.names = FALSE, fileEncoding = 'UTF-8', na = 'NaN')
        },
        error = function(e) {
            error_message <- glue('writing formatted dataset to csv files (NOTE: portal was last updated {update_lag} days ago)')
            error_message_r <- capture.output(cat(as.character(e)))
            fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
            print(glue('Error: {error_message}'))
            stop(e)
        }
    )
}




# 7 - write data to data.ca.gov portal ----------------------------------------
if(check_data == FALSE) {
    tryCatch(
        {
            # Upload file
            resource_update(id = ckan_resource_id,
                            path = output_path)
        },
        error = function(e) {
            error_message <- glue('uploading data to data.ca.gov portal (NOTE: portal was last updated {update_lag} days ago)')
            error_message_r <- capture.output(cat(as.character(e)))
            fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
            print(glue('Error: {error_message}'))
            stop(e)
        }
    )
}




# 8 - send warning message if no recent updates to portal ---------------------
tryCatch(
    {
        ## get updated resource info
        ckan_resource_info_new <- resource_show(id = ckan_resource_id, as = 'table')
        
        ## get date last modified ----
        last_updated_new <- as.Date(ckan_resource_info_new$last_modified)
        update_lag_new <- as.numeric(Sys.Date() - last_updated_new) # number of days
        max_update_lag_exceeded_new <- update_lag_new > max_update_lag 
        
        ## send warning email if last update was too long ago ----
        if (max_update_lag_exceeded_new == TRUE) {
            error_message <- glue('WARNING: the portal has not been updated in over {max_update_lag} days (last portal update was {update_lag_new} days ago)')
            fn_send_email(error_msg = error_message, 
                          error_msg_r = 'NA (no R error)')
            print(glue('{error_message}'))
        }
    },
    error = function(e) {
        error_message <- 'checking how long since last portal update (NOTE: portal was last updated {update_lag} days ago)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)
