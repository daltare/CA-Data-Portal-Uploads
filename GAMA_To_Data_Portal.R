# GAMA - https://gamagroundwater.waterboards.ca.gov/gama/datadownload

# For automated updates, turn off by setting run_script to FALSE
    run_script <- TRUE
    if(run_script == TRUE) {
        
    # NOTE: To schedule this script to run automatically, go to 'Addins' and 'Schedule R scripts on...', then select 
    # the file that calls this script ("C:\\David\\Open_Data_Project\\__CA_DataPortal\\_Call_Scripts\\Call_SurfWater_Script.R.R")
    # and set the time/date option (make sure the date format is %m/%d/%Y)


# Load libraries ####
    library(tidyverse)
    library(janitor)
    library(readr)
    library(ckanr)
    library(dplyr)
    library(lubridate)
        
# delete old versions of the dataset
    delete_old_versions <- TRUE
    filename_gama <- 'GAMA_Statewide_DW_PB_combined'
    # Delete old versions of the files (if desired)
            if (delete_old_versions == TRUE) {
                files_list <- grep(pattern = paste0('^', filename_gama), x = list.files(), value = TRUE) # get a list of all of the files of this type (including the new one) (NOTE: ^ means: starts with..)
                files_to_keep <- c(paste0(filename_gama, '_', Sys.Date() - seq(0,14), '.csv')) # keep the files from the previous 14 days
                files_list_old <- files_list[!(files_list %in% files_to_keep)] # exclude the new file from the list of files to be deleted
                if (length(files_list_old) > 0) {
                    file.remove(files_list_old)
                }
            }

# define direct links to the data
    gama_link <- 'https://gamagroundwater.waterboards.ca.gov/gama/data_download/gama_gama_statewide.zip' # Old: 'http://geotracker.waterboards.ca.gov/gama/data_download/gama_gama_statewide.zip'
    usgs_link <- 'https://gamagroundwater.waterboards.ca.gov/gama/data_download/gama_usgs_statewide.zip' # Old: 'http://geotracker.waterboards.ca.gov/gama/data_download/gama_usgs_statewide.zip'
    
# define data portal resource ID
    resourceID <- '5cef96fd-6f7b-4a83-ac83-aea62d437552' # https://data.ca.gov/dataset/ground-water-water-quality-results/resource/5cef96fd-6f7b-4a83-ac83-aea62d437552

# get the data and read into R #--------------------------------------------------------------------------------------------#
    # GAMA file
        temp <- tempfile()
        download.file(url = gama_link, destfile = temp, method = 'curl')
        data_gama <- readr::read_tsv(unz(temp, 'gama_gama_statewide.txt'), guess_max = 999999)
        unlink(temp)
        
    # USGS file
        temp <- tempfile()
        download.file(url = usgs_link, destfile = temp, method = 'curl')
        data_usgs <- readr::read_tsv(unz(temp, 'gama_usgs_statewide.txt'), guess_max = 999999)
        unlink(temp)
        
# format the dataset #------------------------------------------------------------------------------------------------------#
    # GAMA #------------------------------------------------#
        # check for and filter out any duplicates
            data_gama <- data_gama %>% distinct()        
        # clean up the names
            data_gama <- clean_names(data_gama)
        # check dataset for portal compatibility (for timestamp and numeric fields) and adjust as needed
            glimpse(data_gama)
            # date fields - convert dates into a timestamp field that can be read by the portal
                fields_dates <- c('date')
                for (counter in seq(length(fields_dates))) {
                    # convert the date field to ISO format
                        dates_iso <- mdy(data_gama[[fields_dates[counter]]])
                            # check NAs: sum(is.na(dates_iso))
                    # Convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
                        dates_iso <- as.character(dates_iso)
                            # Check: sum(is.na(dates_iso))
                        dates_iso[is.na(dates_iso)] <- ''
                            # check NAs: sum(is.na(dates_iso))
                    # Insert the revised date field back into the dataset
                        data_gama[,fields_dates[counter]] <- dates_iso
                }
            # numeric fields - ensure all records are compatible with numeric format 
                fields_numeric <- c('results', 'rl', 'latitude', 'longitude', 
                                    'well_depth_ft', 'top_of_screen_ft', 'screen_length_ft')
                for (counter in seq(length(fields_numeric))) {
                    data_gama[,fields_numeric[counter]] <- as.numeric(data_gama[[fields_numeric[counter]]])
                }
            # Convert missing values in text fields to 'NA' (to avoid converting to NaN) !!!!!!!!!!!
                # from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
                data_gama <- data_gama %>% 
                    mutate_if(is.character, ~replace(., is.na(.), 'NA'))
                    # mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))

    # USGS #------------------------------------------------#
        # check for and filter out any duplicates
            data_usgs <- data_usgs %>% distinct()
        # clean up the names
            data_usgs <- clean_names(data_usgs)
        # check dataset for portal compatibility (for timestamp and numeric fields) and adjust as needed
            glimpse(data_usgs)
            # date fields - convert dates into a timestamp field that can be read by the portal
                fields_dates <- c('date')
                for (counter in seq(length(fields_dates))) {
                    # convert the date field to ISO format
                        dates_iso <- mdy(data_usgs[[fields_dates[counter]]])
                            # check NAs: sum(is.na(dates_iso))
                    # Convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
                        dates_iso <- as.character(dates_iso)
                            # Check: sum(is.na(dates_iso))
                        dates_iso[is.na(dates_iso)] <- ''
                            # check NAs: sum(is.na(dates_iso))
                    # Insert the revised date field back into the dataset
                        data_usgs[,fields_dates[counter]] <- dates_iso
                }
            # numeric fields - ensure all records are compatible with numeric format 
                fields_numeric <- c('results', 'rl', 'latitude', 'longitude', 
                                    'well_depth_ft', 'top_of_screen_ft', 'screen_length_ft')
                for (counter in seq(length(fields_numeric))) {
                    data_usgs[,fields_numeric[counter]] <- as.numeric(data_usgs[[fields_numeric[counter]]])
                }
            # Convert missing values in text fields to 'NA' (to avoid converting to NaN) !!!!!!!!!!!
                # from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
                data_usgs <- data_usgs %>% 
                    mutate_if(is.character, ~replace(., is.na(.), 'NA'))
                    # mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))


# combine the gama and usgs datasets #--------------------------------------------------------------------------------------#
    data_combined <- bind_rows(data_gama, data_usgs)


# write out the revised dataset as a .csv file #----------------------------------------------------------------------------#
    out_file <- paste0('GAMA_Statewide_DW_PB_combined_', Sys.Date(),'.csv')
    write_csv(x = data_combined, path = out_file, na = 'NaN')


# write to the open data portal #-------------------------------------------------------------------------------------------#
    # get the data portal API key saved in the local environment (it's available on data.ca.gov by going to your user profile)
        portal_key <- Sys.getenv('data_portal_key')
    # set the ckan defaults    
        ckanr_setup(url = 'https://data.ca.gov/', key = portal_key)
    # get resource info (just as a check)
        ckan_resource_info <- resource_show(id = resourceID, as = 'table')
    # write to the portal
        file_upload <- ckanr::resource_update(id = resourceID, path = out_file)
    }