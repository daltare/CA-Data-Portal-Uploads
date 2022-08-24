# NOTE: To schedule this script to run automatically, go to 'Addins' and 'Schedule R scripts on...', then select 
# the file that calls this script ("C:\\David\\Open_Data_Project\\__CA_DataPortal\\_Call_Scripts\\Call_SurfWater_Script.R.R")
# and set the time/date option (make sure the date format is %m/%d/%Y)

# ENTER THESE VARIABLES #####################################################################################################
    file_active <- 'hr2w_web_data_active'
    file_rtc <- 'hr2w_web_data_rtc'
    extension <- '.xlsx'
    base_url <- 'https://www.waterboards.ca.gov/water_issues/programs/hr2w/docs/data/' # the location where the datasets are posted
    
    # define location where files will be saved
    file_save_location <- 'C:\\David\\_CA_data_portal\\HRTW\\'
    
#############################################################################################################################

# Load libraries ####
    library(tidyverse)
    library(readxl)
    library(ckanr) # this lets you work with the CKAN portal
    library(lubridate) # for working with dates
    library(janitor)
    library(dplyr)
    
# define data portal resource ID
    resourceID_active <- '8b66db8b-3e39-419e-9f1d-c8df6ad4da59' # https://data.ca.gov/dataset/drinking-water-human-right-to-water-regulatory-including-enforcement-actions-information/resource/8b66db8b-3e39-419e-9f1d-c8df6ad4da59
    resourceID_rtc <- '7955a5fa-a874-49da-8f13-a26e78d8a8ec' # https://data.ca.gov/dataset/drinking-water-human-right-to-water-regulatory-including-enforcement-actions-information/resource/7955a5fa-a874-49da-8f13-a26e78d8a8ec
    
# download the most recent dataset #----------------------------------------------------------------------------------------#
    # Create a directory for the current month / year / day
        current_year_month <- paste0(lubridate::year(Sys.Date()), '-', 
                                     formatC(x = lubridate::month(Sys.Date()), digits = 1, flag = 0, format = 'd'), '-', 
                                     formatC(x = lubridate::day(Sys.Date()), digits = 1, flag = 0, format = 'd'))
        if (dir.exists(paste0(file_save_location, current_year_month)) == FALSE) { # make sure that a directory for the current month doesn't already exist
            dir.create(paste0(file_save_location, current_year_month))
        }   
    # in the new directory, download the original (unmodified) files
        # active
            path_active <- paste0(base_url, file_active, extension)
            download.file(url = path_active, destfile = paste0(file_save_location, current_year_month, '//', file_active, extension), method = 'curl')
        # rtc
            path_rtc <- paste0(base_url, file_rtc, extension)
            download.file(url = path_rtc, destfile = paste0(file_save_location, current_year_month, '//', file_rtc, extension), method = 'curl')
    # read the datsets into R
        data_active <-  read_excel(path = paste0(file_save_location, current_year_month, '//' , 
                                                 file_active, extension), guess_max = 999999, na = c('', 'NULL', 'NA'))
        data_rtc <-  read_excel(path = paste0(file_save_location, current_year_month, '//' , file_rtc, extension), 
                                guess_max = 999999, na = c('', 'NULL', 'NA'))
        
        
# format the datasets #------------------------------------------------------------------------------------------------------#
    # Active
        # clean up the names
            # data_active <- clean_names(data_active)
        # re-arrange fields
        #     data_active <- data_active %>% dplyr::select(water_system_number, 
        #                                                  water_system_name,
        #                                                  city,
        #                                                  county,
        #                                                  zipcode,
        #                                                  classification,
        #                                                  population,
        #                                                  service_connections,
        #                                                  regulating_agency,
        #                                                  violation_number,
        #                                                  violation_type_name,
        #                                                  analyte_name,
        #                                                  result,
        #                                                  # result_uom,
        #                                                  mcl,
        #                                                  # mcl_value,
        #                                                  # mcl_uom,
        #                                                  viol_begin_date,
        #                                                  viol_end_date,
        #                                                  enf_action_number,
        #                                                  enf_action_issue_date,
        #                                                  enf_action_type_issued)   
        # # check dataset for portal compatibility and adjust as needed
        #         dplyr::glimpse(data_active)
        #     # date fields - convert dates into a timestamp field that can be read by the portal
        #         fields_dates <- c('viol_begin_date', 'viol_end_date', 'enf_action_issue_date')
        #         for (counter in seq(length(fields_dates))) {
        #             # convert the date field to ISO format
        #                 dates_iso <- ymd(data_active[[fields_dates[counter]]])
        #                     # check NAs: sum(is.na(dates_iso))
        #             # Convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
        #                 dates_iso <- as.character(dates_iso)
        #                     # Check: sum(is.na(dates_iso))
        #                 dates_iso[is.na(dates_iso)] <- ''
        #                     # check NAs: sum(is.na(dates_iso))
        #             # Insert the revised date field back into the dataset
        #                 data_active[,fields_dates[counter]] <- dates_iso
        #         }
        #     # numeric fields - ensure all records are compatible with numeric format 
        #         fields_numeric <- c('population', 'service_connections', 'result', 'mcl_value')
        #         for (counter in seq(length(fields_numeric))) {
        #             data_active[,fields_numeric[counter]] <- as.numeric(data_active[[fields_numeric[counter]]])
        #         }
        # 
        #     # Convert missing values in text fields to 'NA' (to avoid converting to NaN) !!!!!!!!!!!
        #     # from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
        #         data_active <- data_active %>% 
        #             mutate_if(is.character, ~replace(., is.na(.), 'NA'))
        #             # mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))
    
    # RTC
        # # clean up the names
        #     data_rtc <- clean_names(data_rtc)        
        # # re-arrange fields
        #     data_rtc <- data_rtc %>% dplyr::select(water_system_number, 
        #                                            water_system_name,
        #                                            city,
        #                                            county,
        #                                            zipcode,
        #                                            classification,
        #                                            population,
        #                                            service_connections,
        #                                            regulating_agency,
        #                                            violation_number,
        #                                            violation_type_name,
        #                                            analyte_name,
        #                                            result,
        #                                            result_uom,
        #                                            mcl_value,
        #                                            mcl_uom,
        #                                            viol_begin_date,
        #                                            viol_end_date,
        #                                            enf_action_number,
        #                                            enf_action_issue_date,
        #                                            enf_action_type_issued) 
        # # check dataset for portal compatibility and adjust as needed
        #         dplyr::glimpse(data_rtc)
        #     # date fields - convert dates into a timestamp field that can be read by the portal
        #         fields_dates <- c('viol_begin_date', 'viol_end_date', 'enf_action_issue_date')
        #         for (counter in seq(length(fields_dates))) {
        #             # convert the date field to ISO format
        #                 dates_iso <- ymd(data_rtc[[fields_dates[counter]]])
        #                     # check NAs: sum(is.na(dates_iso))
        #             # Convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
        #                 dates_iso <- as.character(dates_iso)
        #                     # Check: sum(is.na(dates_iso))
        #                 dates_iso[is.na(dates_iso)] <- ''
        #                     # check NAs: sum(is.na(dates_iso))
        #             # Insert the revised date field back into the dataset
        #                 data_rtc[,fields_dates[counter]] <- dates_iso
        #         }
        #     # numeric fields - ensure all records are compatible with numeric format 
        #         fields_numeric <- c('population', 'service_connections', 'result', 'mcl_value')
        #         for (counter in seq(length(fields_numeric))) {
        #             data_rtc[,fields_numeric[counter]] <- as.numeric(data_rtc[[fields_numeric[counter]]])
        #         }
        #         
        #     # Convert missing values in text fields to 'NA' (to avoid converting to NaN) !!!!!!!!!!!
        #     # from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
        #         data_rtc <- data_rtc %>% mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))
                                

# write out the revised datasets as .csv files #----------------------------------------------------------------------------#
    # Active
        out_file_active <- paste0(file_save_location, current_year_month, '\\', file_active, '.csv')
        write_csv(x = data_active, file = out_file_active, na = 'NaN')
    # RTC
        out_file_rtc <- paste0(file_save_location, current_year_month, '\\', file_rtc, '.csv')
        write_csv(x = data_rtc, file = out_file_rtc, na = 'NaN')


# write to the open data portal #-------------------------------------------------------------------------------------------#
    # get the data portal API key saved in the local environment (it's available on data.ca.gov by going to your user profile)
        portal_key <- Sys.getenv('data_portal_key')
    # set the ckan defaults    
        ckanr_setup(url = 'https://data.ca.gov/', key = portal_key)
    # Active
        # get resource info (just as a check)
            ckan_resource_info <- resource_show(id = resourceID_active, as = 'table')
        # write to the portal
            file_upload <- ckanr::resource_update(id = resourceID_active, path = out_file_active)
    # RTC
        # get resource info (just as a check)
            ckan_resource_info <- resource_show(id = resourceID_rtc, as = 'table')
        # write to the portal
            file_upload <- ckanr::resource_update(id = resourceID_rtc, path = out_file_rtc)
            