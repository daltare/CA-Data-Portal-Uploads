# NOTE: To schedule this script to run automatically, go to 'Addins' and 'Schedule R scripts on...', then select 
# the file that calls this script ("C:\\David\\Open_Data_Project\\__CA_DataPortal\\_Call_Scripts\\Call_SurfWater_Script.R.R")
# and set the time/date option (make sure the date format is %m/%d/%Y)

# Load packages
    library(ckanr) # this lets you work with the CKAN portal
    library(tidyverse)
    library(janitor)
    library(lubridate)
    
# define direct link to the data
    file_link <- 'https://intapps.waterboards.ca.gov/downloadFile/faces/flatFilesEwrims.xhtml?fileName=ewrims_flat_file.csv'
    # file_link <- 'http://jasperreports/EwrimsFlatFile/ewrims_flat_file.csv'

# define data portal resource ID
    resourceID <- '151c067a-088b-42a2-b6ad-99d84b48fb36' # https://data.ca.gov/dataset/water-rights/resource/151c067a-088b-42a2-b6ad-99d84b48fb36

# define location where files will be saved
    file_save_location <- 'C:\\David\\_CA_data_portal\\Water-Rights\\'
    

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
    
    
# download the files and read data into R
    temp <- tempfile()
    download.file(url = file_link, destfile = temp, method = 'curl')
    df_data <- read_csv(file = temp, 
                        col_types = cols(.default = col_character())) %>% #, quote = '') #%>% select(-X264)
        type_convert()

# clean up the names
    df_data <- clean_names(df_data)

# remove some fields prior to publication
    df_data_filter <- df_data %>% select(-c(application_number_party, pwss_id, fee_due, num_comments, num_attachments, last_update_date, 
                                            primary_owner_entity_type_p, current_status, appl_id, permit_permit_id, license_license_id))

    
# check dataset for portal compatibility and adjust as needed
    # dplyr::glimpse(df_data_filter)
    
    # date fields - convert dates into a timestamp field that can be read by the portal
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

    # numeric fields - ensure all records are compatible with numeric format 
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
            for (counter in seq(length(fields_numeric))) {
                df_data_filter[,fields_numeric[counter]] <- as.numeric(df_data_filter[[fields_numeric[counter]]])
            }
    
    # Convert missing values in text fields to 'NA' (to avoid converting to NaN) !!!!!!!!!!!
    # from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
        df_data_filter <- df_data_filter %>% 
            mutate_if(is.character, ~replace(., is.na(.), 'NA'))
            # mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))
    
# write out the revised dataset as a .csv file
    out_file <- paste0(file_save_location, 'water_rights_list_', Sys.Date(), '.csv')
    write_csv(x = df_data_filter, file = out_file, na = 'NaN')
    
    
# write to the open data portal
    # get the data portal API key saved in the local environment (it's available on data.ca.gov by going to your user profile)
        portal_key <- Sys.getenv('data_portal_key')
    # set the ckan defaults
        ckanr_setup(url = 'https://data.ca.gov/', key = portal_key)
    # get resource info (just as a check)
        ckan_resource_info <- resource_show(id = resourceID, as = 'table')
    # write to the portal
        file_upload <- ckanr::resource_update(id = resourceID, path = out_file)
        