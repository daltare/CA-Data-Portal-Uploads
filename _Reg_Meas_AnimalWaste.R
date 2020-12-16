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
    resourceID <- 'c16335af-f2dc-41e6-a429-f19edba5b957' # https://data.ca.gov/dataset/surface-water-water-quality-regulated-facility-information/resource/c16335af-f2dc-41e6-a429-f19edba5b957

# download the files and read data into R
    temp <- tempfile()
    download.file(url = file_link, destfile = temp, method = 'curl')
    df_data <- readr::read_tsv(file = temp, guess_max = 999999, quote = '') %>% 
        clean_names() %>% 
        select(-starts_with(c('X', 'x'))) %>% 
        # select(-X264) %>% 
        {.}

# select the rows where 'PROGRAM CATEGORY' is 'ANIMALWASTE', 'STATUS' is 'Active', and 'REG MEASURE TYPE' is not '13267 Letter (Non-Enforcement)' or 'Letter'
    df_data_filter <- df_data %>% filter(program_category == 'ANIMALWASTE',
                                         status == 'Active',
                                         reg_measure_type != '13267 Letter (Non-Enforcement)',
                                         reg_measure_type != 'Letter')

# select just the relevant fields
    df_data_filter <- df_data_filter %>% select("reg_measure_id","reg_measure_type","reg_measure_title",
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

    
# check dataset for portal compatibility and adjust as needed
    dplyr::glimpse(df_data_filter)
    
    # date fields - convert dates into a timestamp field that can be read by the portal
        fields_dates <- c('effective_date', 'expiration_review_date', 'termination_date', 
                          'adoption_date', 'rescission_date')
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
        fields_numeric <- c('number_of_amendments', 'latitude_decimal_degrees', 'longitude_decimal_degrees',
                            'cafo_population', 'animal_equivalent_units_aeu')
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
    out_file <- paste0('reg_meas_export_CAFO_', Sys.Date(), '.csv')
    write_csv(x = df_data_filter, path = out_file, na = 'NaN')
    
    
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