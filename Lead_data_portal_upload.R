# Lead in Schools - https://www.waterboards.ca.gov/drinking_water/certlic/drinkingwater/leadsamplinginschools.html

# For automated updates, turn off by setting run_script to FALSE
    run_script <- TRUE
    if(run_script == TRUE) {
        
    # NOTE: To schedule this script to run automatically, go to 'Addins' and 'Schedule R scripts on...', then select 
    # the file that calls this script ("C:\\David\\Open_Data_Project\\__CA_DataPortal\\_Call_Scripts\\Call_SurfWater_Script.R.R")
    # and set the time/date option (make sure the date format is %m/%d/%Y)

# ENTER THESE VARIABLES #####################################################################################################
    filename <- 'monthlyposting'
    extension <- '.xlsx'
    base_url <- 'https://www.waterboards.ca.gov/drinking_water/certlic/drinkingwater/documents/leadsamplinginschools/' # the location where the datasets are posted
    # base_url <- 'https://www.waterboards.ca.gov/drinking_water/certlic/drinkingwater/documents/leadsamplinginschools/rptmonthlyposting.xls' # the location where the datasets are posted
#############################################################################################################################

# Load libraries ####
    library(tidyverse)
    library(readxl)
    library(ckanr) # this lets you work with the CKAN portal
    library(lubridate) # for working with dates
    library(janitor)
    library(dplyr)

# define data portal resource ID
    resourceID <- '5ebb2d68-1186-4937-acaf-8564c9a01ed6' # https://data.ca.gov/dataset/drinking-water-results-of-lead-sampling-of-drinking-water-in-california-schools/resource/5ebb2d68-1186-4937-acaf-8564c9a01ed6
    
# download the most recent dataset #----------------------------------------------------------------------------------------#
    # Create a directory for the current month / year
        current_year_month <- paste0(lubridate::year(Sys.Date()), '-', formatC(x = lubridate::month(Sys.Date()), digits = 1, flag = 0, format = 'd'))
        if (dir.exists(current_year_month) == FALSE) { # make sure that a directory for the current month doesn't already exist
            dir.create(current_year_month)
        }   
    # in the new directory, download the original (unmodified) file
        path <- paste0(base_url, filename, extension)
        download.file(url = path, destfile = paste0(current_year_month, '//', filename, extension), method = 'curl')
    # read the datset into R
        data_lead <-  read_excel(path = paste0(current_year_month, '//' , filename, extension))
        
# format the dataset #------------------------------------------------------------------------------------------------------#
    # clean up the names
        data_lead <- clean_names(data_lead)
    # check dataset for portal compatibility and adjust as needed
        dplyr::glimpse(data_lead)
    # date fields - convert dates into a timestamp field that can be read by the portal
        fields_dates <- c('sample_date')
        for (counter in seq(length(fields_dates))) {
            # convert the date field to ISO format
                dates_iso <- ymd(data_lead[[fields_dates[counter]]])
                    # check NAs: sum(is.na(dates_iso))
            # Convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
                dates_iso <- as.character(dates_iso)
                    # Check: sum(is.na(dates_iso))
                dates_iso[is.na(dates_iso)] <- ''
                    # check NAs: sum(is.na(dates_iso))
            # Insert the revised date field back into the dataset
                data_lead[,fields_dates[counter]] <- dates_iso
        }
    # numeric fields - ensure all records are compatible with numeric format 
        fields_numeric <- c('result')
        for (counter in seq(length(fields_numeric))) {
            data_lead[,fields_numeric[counter]] <- as.numeric(data_lead[[fields_numeric[counter]]])
        }
    # Convert missing values in text fields to 'NA' (to avoid converting to NaN) !!!!!!!!!!!
        # from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
        data_lead <- data_lead %>% mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))

        
# write out the revised dataset as a .csv file #----------------------------------------------------------------------------#
    out_file <- paste0(current_year_month, '//', filename, '.csv')
    write_csv(x = data_lead, path = out_file, na = 'NaN')


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