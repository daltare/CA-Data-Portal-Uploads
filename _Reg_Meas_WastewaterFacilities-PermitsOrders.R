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

# define direct link to the data
    file_link <- 'https://intapps.waterboards.ca.gov/downloadFile/faces/flatFilesCiwqs.xhtml?fileName=reg_meas_export.txt' 
    # 'http://jasperreports/JasperReports/FlatFiles/reg_meas_export.txt'
    
# define data portal resource ID
    resourceID <- '2446e10e-8682-4d7a-952e-07ffe20d4950' # https://data.ca.gov/dataset/surface-water-water-quality-regulated-facility-information/resource/2446e10e-8682-4d7a-952e-07ffe20d4950

# download the files and read data into R
    temp <- tempfile()
    download.file(url = file_link, destfile = temp, method = 'curl')
    df_data <- readr::read_tsv(file = temp, guess_max = 999999, quote = '') %>% 
        # clean_names() %>% 
        select(-starts_with(c('X', 'x'))) %>%
        # select(-X264) %>% 
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
    out_file <- paste0('reg_meas_export_WastewaterPermitsOrders_', Sys.Date(), '.csv')
    write_csv(x = dataset_revised, path = out_file, na = 'NaN')
    
        
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