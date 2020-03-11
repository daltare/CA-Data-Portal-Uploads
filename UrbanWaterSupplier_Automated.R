# For automated scripting, turn off by setting run_script to FALSE
    # run_script <- TRUE
    # if(run_script == TRUE) {
    
    # NOTE: To schedule this script to run automatically, go to 'Addins' and 'Schedule R scripts on...', then select 
    # the file that calls this script ("C:\\David\\Open_Data_Project\\__CA_DataPortal\\_Call_Scripts\\Call_UrbanSupplierConservation.R")
    # and set the time/date option (make sure the date format is %m/%d/%Y)

# ENTER THESE VARIABLES #####################################################################################################
    base_url <- 'https://www.waterboards.ca.gov/water_issues/programs/conservation_portal/docs/' # the location where the conservation datasets are posted
    PWSID_Lookup_File <- 'Supplier_PWSID_Lookup_FINAL_revised_2019-10-01.xlsx' # change this if there are corrections to the file
    ckan_resource_id <- '0c231d4c-1ea7-43c5-a041-a3a6b02bac5e' # https://data.ca.gov/dataset/drinking-water-public-water-system-operations-monthly-water-production-and-conservation-information/resource/0c231d4c-1ea7-43c5-a041-a3a6b02bac5e
#############################################################################################################################
    

# Load packages ####
    library(tidyverse)
    library(readxl)
    library(reticulate) # this lets you import packages/functions/etc. from python into R
    library(lubridate) # for working with dates
    library(ckanr)
    
# set the ckanr defaults
    # get the data portal API key saved in the local environment (it's available on data.ca.gov by going to your user profile)
        portal_key <- Sys.getenv('data_portal_key')
    # set defaults
        ckanr::ckanr_setup(url = 'https://data.ca.gov/', key = portal_key)
        

# OLD STUFF FROM PYTHON VERSION        
# # Get the variables set in the Windows environment (to change these, search Windows for 'Edit environment variables for your account') ####
# # Could also use: Sys.getenv() to get the environment variables (e.g., Sys.getenv('DCG_user'))
#     py.os <- import("os") # import the python library 'os'
#     user <- py.os$getenv('DCG_user')
#     password <-  py.os$getenv('DCG_pw')
#     URI <- py.os$getenv('URI')
#     # SERVER  <- py.os$getenv('SERVER') # Not used - only for getting data from the CEDEN datamart
#     # UID <- py.os$getenv('UID') # Not used - only for getting data from the CEDEN datamart
#     # PWD <- py.os$getenv('PWD') # Not used - only for getting data from the CEDEN datamart
# 
# # Import the python library 'dkan.client' and use it to connect to the portal via the REST API, then get some information ####
# # about a node as a check that the connection is successful
#     py.dkan.client <- import('dkan.client')
#     Node <- 1801
#     api <- py.dkan.client$DatasetAPI(URI, user, password, TRUE)
#     r <- api$node('retrieve', node_id = Node)
#     # print(r$json())
#     node_info <- r$json()
#     current_dataportal_filename <- node_info$field_upload$und[[1]]$filename
#     print(current_dataportal_filename) # this is just a test to make sure the API connection is successful

# get information about the resource currently on the data portal
    ckan_resource_info <- ckanr::resource_show(id = ckan_resource_id, as = 'table')
        ckan_resource_file <- str_split(string = ckan_resource_info$url, pattern = '/')[[1]]
        ckan_resource_file <- ckan_resource_file[length(ckan_resource_file)]
        
# DOWNLOAD THE MOST RECENT DATASET FROM THE WATERBOARDS CONSERVATION PORTAL - THIS IS THE SOURCE DATA ####
# This loop cycles through each day of the current month until it finds a file posted in the current month.
# It assumes that the file is formated as 'YYYYmmm/uw_supplier_dataMMDDYY.xlsx' (e.g., for August 2017, 
# it's: '2017aug/uw_supplier_data080117.xlsx'), where the base URL is: 
# 'http://www.waterboards.ca.gov/water_issues/programs/conservation_portal/docs/'.
# If it finds a file, it then downloads the file locally. 
        status <- 'File does not exist'
        i <- 1
        # Check to see if the file exists
        while((status == 'File does not exist') & (i < 32)) {
            test.link <- paste0(base_url, year(Sys.Date()), tolower(month.abb[month(Sys.Date())]), # build the link for a given date
                                '/uw_supplier_data', sprintf('%02d',month(Sys.Date())), sprintf('%02d',i), year(Sys.Date())-2000, '.xlsx')
            result <- suppressWarnings(tryCatch(readLines(con = test.link, n = 10), # check to see if a file with the given date exists
                                              error=function(e) return("Error")))
            if(result[1] != 'Error' & result[1]!= '<!doctype html>') {status <- 'File exists'}
            # sometimes the month name uses 4 characters instead of 3 - e.g. July 2018 - if the above didn't work, rebuild the link with the first 4 letters and try that
            if (status == 'File does not exist') {
                test.link <- paste0(base_url, year(Sys.Date()), tolower(substr(month.name[month(Sys.Date())],1,4)), # build the link for a given date
                                    '/uw_supplier_data', sprintf('%02d',month(Sys.Date())), sprintf('%02d',i), year(Sys.Date())-2000, '.xlsx')
                result <- suppressWarnings(tryCatch(readLines(con = test.link, n = 10), # check to see if a file with the given date exists
                                                    error=function(e) return("Error")))
                if(result[1] != 'Error' & result[1]!= '<!doctype html>') {status <- 'File exists'}
            }
            # try again with an underscore before the date
            if (status == 'File does not exist') {
                test.link <- paste0(base_url, year(Sys.Date()), tolower(month.abb[month(Sys.Date())]), # build the link for a given date
                                    '/uw_supplier_data_', sprintf('%02d',month(Sys.Date())), sprintf('%02d',i), year(Sys.Date())-2000, '.xlsx')
                result <- suppressWarnings(tryCatch(readLines(con = test.link, n = 10), # check to see if a file with the given date exists
                                                    error=function(e) return("Error")))
                if(result[1] != 'Error' & result[1]!= '<!doctype html>') {status <- 'File exists'}
            }
            if(status == 'File does not exist') {i <- i + 1} # increment i if the status is still the same
            if(i > 31) {break} # just to make sure it doesn't go into an endless loop, stops if it goes beyond day 31 in the month
        }
        # print(paste0('Status: ', status)) # just a check, not needed
        # Download the file, in a newly created directory called 'YYYY.MM'
        if(status == 'File exists') {
            dest_filename <- paste0('uw_supplier_data', sprintf('%02d',month(Sys.Date())), sprintf('%02d',i), 
                                    year(Sys.Date())-2000, '.xlsx')
            # check to see if the downloaded data is the same as the existing data on the CA portal - if so, no update needed
                check_data <- identical(strsplit(ckan_resource_file, '.csv')[[1]], strsplit(dest_filename, '.xlsx')[[1]])
                if(check_data == FALSE) { # only do this if there is new data that hasn't already been uploaded to the CA data portal
                    directory_name <- paste0(year(Sys.Date()), '.', sprintf('%02d',month(Sys.Date())))
                    dir.create(paste0('..\\', directory_name), showWarnings = FALSE)
                    download.file(url = test.link, 
                                  destfile = paste0('..\\', directory_name, '\\', dest_filename), 
                                  method = 'curl')
                    # print('File downloaded') # just a check, not needed
                }
        }


# FORMAT THE DATA FOR THE CA DATA PORTAL ####
    if(check_data == FALSE) { # only do this if there is new data that hasn't already been uploaded to the CA data portal
        # read in the new data to R
        dataset <- read_excel(paste0('..\\', directory_name, '\\', dest_filename), guess_max = 50000)
        dataset <- as.data.frame(dataset)
        dataset_original <- dataset # create a copy of the original for comparison
        
        # enter the new column names
        new.names <- c('Supplier_Name', 'Stage_Invoked', 'Mandatory_Restrictions', 'Reporting_Month', 'Production_Reported',
                       '2013_Production_Reported','CII_Reported','Agriculture_Reported', '2013_Agriculture_Reported',
                       'Recycled_Reported','Units','Qualification','Population_Served','R_GPCD_Reported','Enforcement_Actions',
                       'Implementation','Conservation_Standard','Ag_Cert','Production_Calculated','2013_Production_Calculated',
                       'CII_Calculated','R_GPCD_Calculated','Percent_Residential_Use','Comments_Corrections','Hydrologic_Region',
                       'Watering_Days_Per_Week','Complaints','Follow_Ups','Warnings','Penalties_Rate','Penalties_Other',
                       'Enforcement_Comments')
        
        # change the column names
        names(dataset) <- new.names
        
        # Populate the PWSIDs
        PWSID_lookup <- read_excel(PWSID_Lookup_File)
        PWSID_lookup <- PWSID_lookup %>% select(-PWSID)
        dataset <- dataset %>% left_join(PWSID_lookup, by = 'Supplier_Name')
        
        # reorder the columns
        dataset <- dataset %>% select(Supplier_Name, Corrected_PWSID, Stage_Invoked:Enforcement_Comments)
        names(dataset)[2] <- 'PWSID'
        
        # Replace various "Not Available" codes with NAs
        dataset <- dataset %>% mutate_if(is.character, list(~case_when(. == 'N/A' ~ NA_character_, 
                                                                       . == 'NA' ~ NA_character_,
                                                                       . == 'na' ~ NA_character_,
                                                                       . == 'n/a' ~ NA_character_,
                                                                       . == 'not avail.' ~ NA_character_,
                                                                       . == 'uk' ~ NA_character_,
                                                                       . == 'Null' ~ NA_character_,
                                                                       . == 'No' ~ NA_character_,
                                                                       TRUE ~ .)))
        # Convert columns that should be numeric from character to numeric
        dataset <- dataset %>% mutate(Production_Reported = as.numeric(Production_Reported),
                                      `2013_Production_Reported` = as.numeric(`2013_Production_Reported`),
                                      CII_Reported = as.numeric(CII_Reported),
                                      Agriculture_Reported = as.numeric(Agriculture_Reported),
                                      `2013_Agriculture_Reported` = as.numeric(`2013_Agriculture_Reported`),
                                      Recycled_Reported = as.numeric(Recycled_Reported),
                                      Population_Served = as.numeric(Population_Served),
                                      R_GPCD_Reported = as.numeric(R_GPCD_Reported),
                                      Production_Calculated = as.numeric(Production_Calculated),
                                      `2013_Production_Calculated` = as.numeric(`2013_Production_Calculated`),
                                      CII_Calculated = as.numeric(CII_Calculated),
                                      R_GPCD_Calculated = as.numeric(R_GPCD_Calculated),
                                      Percent_Residential_Use = as.numeric(Percent_Residential_Use),
                                      Watering_Days_Per_Week = as.numeric(Watering_Days_Per_Week),
                                      Complaints = as.numeric(Complaints),
                                      Follow_Ups = as.numeric(Follow_Ups),
                                      Warnings = as.numeric(Warnings),
                                      Penalties_Rate = as.numeric(Penalties_Rate),
                                      Penalties_Other = as.numeric(Penalties_Other))
            # use to check a field for non-numeric values
                # field_values <- dataset$Watering_Days_Per_Week
                # field_values_numeric <- as.numeric(field_values)
                # field_values[!is.na(field_values) & is.na(field_values_numeric)]

        # replace blanks with NAs in character fields (use NaN when writing to csv to take care of missing values in numeric fields, to work with requirements of the CA data portal for numeric values)
        # tf <- is.na(dataset)
        # dataset[tf] <- 'NA'
        dataset <- dataset %>% mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))
        
        # convert the Reporting_Month field into a date 
        dataset$Reporting_Month <- as.Date(dataset$Reporting_Month, origin = "1899-12-30")
            # if there are records in this field that can't be converted to Date format, convert the NAs to '' (empty text string) - needed to comply with requirements of CA data portal
                sum(is.na(dataset$Reporting_Month))
                dataset$Reporting_Month <- as.character(dataset$Reporting_Month)
                dataset$Reporting_Month[is.na(dataset$Reporting_Month)] <- ''
        
        # # add a field that can be read as a timestamp - Not needed if the Reporting_Month field will be set as timestamp type on the data portal
        #     # first check for Reporting_Month records that can't be recognized as a timestamp, and convert them into NAs in the new field
        #         tf_date <- is.na(ymd(dataset$Reporting_Month))
        #         dataset <- dataset %>% mutate(Reporting_Month_timestamp = Reporting_Month)
        #         dataset$Reporting_Month_timestamp[tf_date] <- NA
        #     # create the timestamps
        #         dataset <- dataset %>% mutate(Reporting_Month_timestamp = case_when(is.na(Reporting_Month) ~ '',
        #                                                                             TRUE ~ paste0(Reporting_Month, ' 00:00:00')))
        # Write out the formatted file as a CSV
            output_path <- paste0('..\\', directory_name, '\\', strsplit(dest_filename, '.xlsx')[[1]], '.csv')
            write.csv(dataset, file = output_path, row.names = FALSE, fileEncoding = 'UTF-8', na = 'NaN')
}

# WRITE THE FORMATTED FILE TO THE CA DATA PORTAL, USING THE CKANR PACKAGE
    if(check_data == FALSE) {
        # Upload file 
            resource_update(id = ckan_resource_id, 
                                   path = output_path)
        # # OLD METHOD - USING PYTHON PACKAGE THAT INTERFACES WITH THE REST API ####
        #     fileWritten = output_path
        #     r = api$attach_file_to_node(file = fileWritten, node_id=Node, field = 'field_upload' )
    }
        
    # }