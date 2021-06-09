# NOTE: To schedule this script to run automatically, go to 'Addins' and 'Schedule R scripts on...', then select 
# the file that calls this script ("C:\\David\\Open_Data_Project\\__CA_DataPortal\\_Call_Scripts\\Call_SurfWater_Script.R.R")
# and set the time/date option (make sure the date format is %m/%d/%Y)

# Load packages
    library(ckanr) # this lets you work with the CKAN portal
    library(tidyverse)
    library(janitor)
    library(dplyr)
    library(lubridate)

# define direct link to the data
    file_link <- 'https://intapps.waterboards.ca.gov/downloadFile/faces/flatFilesCiwqs.xhtml?fileName=reg_meas_export.txt' 
    # ' 'http://jasperreports/JasperReports/FlatFiles/reg_meas_export.txt'
    
# define location where files will be saved
    file_save_location <- 'C:\\David\\_CA_data_portal\\Surface-Water-Datasets\\'
    
# define data portal resource ID
    resourceID <- '2446e10e-8682-4d7a-952e-07ffe20d4950' # https://data.ca.gov/dataset/surface-water-water-quality-regulated-facility-information/resource/2446e10e-8682-4d7a-952e-07ffe20d4950

# delete old versions of the dataset
    delete_old_versions <- TRUE
    filename_delete <- 'reg_meas_export_WastewaterPermitsOrders_'
    # Delete old versions of the files (if desired)
            if (delete_old_versions == TRUE) {
                files_list <- grep(pattern = paste0('^', filename_delete), x = list.files(file_save_location), value = TRUE) # get a list of all of the files of this type (including the new one) (NOTE: ^ means: starts with..)
                # files_list_old <- files_list[files_list != paste0(filename, '_', Sys.Date(), '_Raw.txt')] # exclude the new file from the list of files to be deleted
                files_to_keep <- c(paste0(filename_delete, Sys.Date() - seq(0,7), '.csv')) # keep the files from the previous 7 days
                files_to_keep <- files_to_keep[files_to_keep %in% files_list]
                files_list_old <- files_list[!(files_list %in% files_to_keep)] # exclude the new file from the list of files to be deleted
                if (length(files_list_old) > 0 & length(files_to_keep) > 0) {
                    file.remove(paste0(file_save_location, files_list_old))
                }
            }
    
# download the files and read data into R
    temp <- tempfile()
    download.file(url = file_link, destfile = temp, method = 'curl')
    df_data <- readr::read_tsv(file = temp, col_types = cols(.default = col_character()), quote = '') %>% 
        type_convert() %>% 
        # clean_names() %>% 
        select(-starts_with(c('X', 'x'))) %>%
        {.}
    
# define the fields to keep
    # fields_keep_original <- c('REG MEASURE ID','REG MEASURE TYPE','ORDER #','NPDES # CA#','PROGRAM','PROGRAM CATEGORY','WDID','MAJOR-MINOR','STATUS','EFFECTIVE DATE','EXPIRATION/REVIEW DATE','TERMINATION DATE','ADOPTION DATE','WDR REVIEW - AMEND','WDR REVIEW - REVISE/RENEW','WDR REVIEW - RESCIND','WDR REVIEW - NO ACTION REQUIRED','WDR REVIEW - PENDING','WDR REVIEW - PLANNED', 'INDIVIDUAL/GENERAL','FEE CODE','DESIGN FLOW','THREAT TO WATER QUALITY','COMPLEXITY','PRETREATMENT','POPULATION (MS4)/ACRES','RECLAMATION','FACILITY WASTE TYPE','FACILITY WASTE TYPE 2','# OF AMENDMENTS','FACILITY ID','FACILITY REGION','FACILITY NAME','PLACE TYPE','PLACE ADDRESS','PLACE CITY','PLACE ZIP','PLACE COUNTY','LATITUDE DECIMAL DEGREES','LONGITUDE DECIMAL DEGREES','Location 1')
    fields_keep <- c('REG MEASURE ID','REG MEASURE TYPE','ORDER #','NPDES # CA#', 'PROGRAM CATEGORY','WDID','MAJOR-MINOR','STATUS','EFFECTIVE DATE','EXPIRATION/REVIEW DATE','TERMINATION DATE','ADOPTION DATE','WDR REVIEW - AMEND','WDR REVIEW - REVISE/RENEW','WDR REVIEW - RESCIND','WDR REVIEW - NO ACTION REQUIRED','WDR REVIEW - PENDING','WDR REVIEW - PLANNED','STATUS ENROLLEE','INDIVIDUAL/GENERAL','FEE CODE','DESIGN FLOW','THREAT TO WATER QUALITY','COMPLEXITY','PRETREATMENT','POPULATION (MS4)/ACRES','RECLAMATION','FACILITY WASTE TYPE','FACILITY WASTE TYPE 2','# OF AMENDMENTS','FACILITY ID','FACILITY REGION','FACILITY NAME','PLACE TYPE','PLACE ADDRESS','PLACE CITY','PLACE ZIP','PLACE COUNTY','LATITUDE DECIMAL DEGREES','LONGITUDE DECIMAL DEGREES')
    
# select just the relevant fields
    dataset_revised <- df_data %>% select(all_of(fields_keep))

# select the rows where 'STATUS' is either 'Active' or 'Historical
    dataset_revised <- dataset_revised %>% filter(STATUS == 'Active' | STATUS == 'Historical')
    
# clean up the names
    dataset_revised <- dataset_revised %>% clean_names()
    
# check dataset for portal compatibility and adjust as needed
    glimpse(dataset_revised)
    
    # date fields
        fields_dates <- c('effective_date', 'expiration_review_date', 'termination_date', 'adoption_date', 
                          'wdr_review_amend', 'wdr_review_revise_renew', 'wdr_review_rescind', 'wdr_review_no_action_required', 
                          'wdr_review_pending', 'wdr_review_planned')
        # convert dates and times into a timestamp field that can be read by the portal
            for (counter in seq(length(fields_dates))) {
                # convert the date field to ISO format
                    dates_iso <- mdy(dataset_revised[[fields_dates[counter]]])
                        # check NAs: sum(is.na(dates_iso))
                # Convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
                    dates_iso <- as.character(dates_iso)
                        # check: sum(is.na(dates_iso))
                    dates_iso[is.na(dates_iso)] <- ''
                        # check NAs: sum(is.na(dates_iso))
                # Insert the revised date field back into the dataset
                    dataset_revised[,fields_dates[counter]] <- dates_iso
            }
    
    # numeric fields - ensure all records are compatible with numeric format 
        fields_numeric <- c('design_flow', 'threat_to_water_quality', 'population_ms4_acres', 'number_of_amendments', 
                            'latitude_decimal_degrees', 'longitude_decimal_degrees')
        # convert to numeric
            for (counter in seq(length(fields_numeric))) {
                dataset_revised[,fields_numeric[counter]] <- as.numeric(dataset_revised[[fields_numeric[counter]]])
            }
        
    # Convert missing values in text fields to 'NA' (to avoid converting to NaN) !!!!!!!!!!!
    # from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
        dataset_revised <- dataset_revised %>% 
            mutate_if(is.character, ~replace(., is.na(.), 'NA'))
            # mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))
        
    glimpse(dataset_revised)
    
# write out the revised dataset as a .csv file
    out_file <- paste0(file_save_location, 'reg_meas_export_WastewaterPermitsOrders_', Sys.Date(), '.csv')
    write_csv(x = dataset_revised, file = out_file, na = 'NaN')
    
        
# write to the open data portal
    # get the data portal API key saved in the local environment (it's available on data.ca.gov by going to your user profile)
        portal_key <- Sys.getenv('data_portal_key')
    # set the ckan defaults    
        ckanr_setup(url = 'https://data.ca.gov/', key = portal_key)
    # get resource info (just as a check)
        ckan_resource_info <- resource_show(id = resourceID, as = 'table')
    # write to the portal
        file_upload <- ckanr::resource_update(id = resourceID, path = out_file)