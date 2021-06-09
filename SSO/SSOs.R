# source data from:
# https://www.waterboards.ca.gov/water_issues/programs/sso/docs/index.php

# For automated updates, turn off by setting run_script to FALSE
    run_script <- TRUE
    if(run_script == TRUE) {
        
    # NOTE: To schedule this script to run automatically, go to 'Addins' and 'Schedule R scripts on...', then select 
    # the file that calls this script ("C:\\David\\Open_Data_Project\\__CA_DataPortal\\_Call_Scripts\\Call_SurfWater_Script.R.R")
    # and set the time/date option (make sure the date format is %m/%d/%Y)

# Load packages
    library(ckanr) # this lets you work with the CKAN portal
    library(tidyverse)
    library(janitor)
    library(dplyr)
    library(lubridate)
    
# define direct links to the data
    file_link_list <- list(
        SSO = 'https://www.waterboards.ca.gov/water_issues/programs/sso/docs/data_files/SSO.txt',
        SSMP = 'https://www.waterboards.ca.gov/water_issues/programs/sso/docs/data_files/SSMP.txt',
        Questionnaire = 'https://www.waterboards.ca.gov/water_issues/programs/sso/docs/data_files/Questionnaire.txt',
        PRA = 'https://www.waterboards.ca.gov/water_issues/programs/sso/docs/data_files/PRA.txt',
        PLSD = 'https://www.waterboards.ca.gov/water_issues/programs/sso/docs/data_files/PLSD.txt',
        No_spill = 'https://www.waterboards.ca.gov/water_issues/programs/sso/docs/data_files/No_spill.txt'
    )

# define data portal resource IDs
    resourceID_list <- list(
        SSO = '72d6fda2-427b-4482-9a87-d78272e3b35e',
        SSMP = '',
        Questionnaire = '',
        PRA = '',
        PLSD = '',
        No_spill = ''
    )
    
# define date fields for each dataset
    date_fields_list <- list(
        SSO = c('spill_created_dt', 'original_certified_date',  # DMY
                'submit_draft_date', 'cert_dt', # MDY
                'start_dt',  'agency_notify_dt', 'oprtor_arrvl_dt', # MDY_HM
                'est_end_dt', 'response_complete_dt'),
        SSMP = c(''),
        Questionnaire = c(''),
        PRA = c(''),
        PLSD = c(''),
        No_spill = c('')
    )
    
# define numeric fields for each dataset
    numeric_fields_list <- list(
        SSO = c('spill_vol_reach_land', 'spill_vol', 
                'spill_vol_recover', 'spill_vol_reach_surf', 
                'lattitude_decimal_degrees', 'longitude_decimal_degrees',
                'sso_number_appear_points'
        ),
        SSMP = c(''),
        Questionnaire = c(''),
        PRA = c(''),
        PLSD = c(''),
        No_spill = c('')
    )


for (counter in seq_along(file_link_list)) {
    file_link <- file_link_list[[counter]]
    file_name <- names(file_link_list)[[counter]]
    resourceID <- resourceID_list[[file_name]]
    fields_dates <- date_fields_list[[file_name]]
    fields_numeric <- numeric_fields_list[[file_name]]
    
    # download the files and read data into R
    temp <- tempfile()
    download.file(url = file_link, destfile = temp, method = 'curl')
    df_data <- readr::read_tsv(file = temp, guess_max = 999999, quote = '') %>% 
        clean_names() %>% 
        select(-starts_with(c('X', 'x'))) %>% 
        {.}

    
# check dataset for portal compatibility and adjust as needed
    dplyr::glimpse(df_data)
    
    # date fields - convert dates into a timestamp field that can be read by the portal
            # range(df_data$response_complete_dt, na.rm = T)
         for (counter in seq(length(fields_dates))) {
            # convert the date field to ISO format
             if (counter %in% 1:2) {
                dates_iso <- dmy(df_data[[fields_dates[counter]]])
             } else if (counter %in% 3:4) {
                 dates_iso <- mdy(df_data[[fields_dates[counter]]])
             } else {
                 dates_iso <- mdy_hm(df_data[[fields_dates[counter]]])
             }
                    # check NAs: sum(is.na(dates_iso))
                    range(dates_iso, na.rm = T)
            # Convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
                dates_iso <- as.character(dates_iso)
                    # Check: sum(is.na(dates_iso))
                dates_iso[is.na(dates_iso)] <- ''
                    # check NAs: sum(is.na(dates_iso))
            # Insert the revised date field back into the dataset
                df_data[,fields_dates[counter]] <- dates_iso
         }
        

    # numeric fields - ensure all records are compatible with numeric format 
        # convert to numeric
            for (counter in seq(length(fields_numeric))) {
                df_data[,fields_numeric[counter]] <- as.numeric(df_data[[fields_numeric[counter]]])
            }
    
    # Convert missing values in text fields to 'NA' (to avoid converting to NaN) !!!!!!!!!!!
    # from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
        df_data <- df_data %>% 
            mutate_if(is.character, ~replace(., is.na(.), 'NA'))
            # mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))
    
# write out the revised dataset as a .csv file
    out_file <- paste0(file_name, '_', Sys.Date(), '.csv')
    write_csv(x = df_data, file = out_file, na = 'NaN')
    
# write to the open data portal
    # get the data portal API key saved in the local environment (it's available on data.ca.gov by going to your user profile)
        portal_key <- Sys.getenv('data_portal_key')
    # set the ckan defaults    
        ckanr_setup(url = 'https://data.ca.gov/', key = portal_key)
    # get resource info (just as a check)
        ckan_resource_info <- resource_show(id = resourceID, as = 'table')
    # write to the portal
        file_upload <- ckanr::resource_update(id = resourceID, path = out_file)
}

    }