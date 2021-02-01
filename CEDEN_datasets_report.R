library(ckanr) # this lets you work with the CKAN portal
library(tidyverse)
library(janitor)
library(dplyr)
library(lubridate)
library(httr)

# setup
# Portal Stuff
    # get the data portal API key saved in the local environment (it's available on data.ca.gov by going to your user profile)
        portal_key <- Sys.getenv('data_portal_key')
    # set the ckan defaults
        ckanr_setup(url = 'https://data.ca.gov/', key = portal_key)
        
# package IDs
    list_package_id <- list(benthic = 'c14a017a-8a8c-42f7-a078-3ab64a873e32', 
                            habitat = 'f5edfd1b-a9b3-48eb-a33e-9c246ab85adf',
                            tissue = '38cb5cca-1500-42e7-b359-e8e3c5d1e087',
                            toxicity = 'c5a4ab7e-4d9b-4b31-bc08-807984d44102',
                            chemistry = '28d7a81d-6458-47bd-9b79-4fcbfbb88671')


# get info about packages
    for (i_package in seq_along(names(list_package_id))) {
        package_id <- list_package_id[[i_package]]
        package_info <- package_show(package_id, as = 'table')
        package_resources <- package_info$resources
        
        package_data <- package_resources %>% 
            filter(format %in% c('CSV', 'ZIP')) %>% 
            select(name, format, datastore_active, datastore_contains_all_records_of_source_file, 
                   size, last_modified, id, url) %>% 
            mutate(datastore_active = as.logical(datastore_active),
                   datastore_contains_all_records_of_source_file = as.logical(datastore_contains_all_records_of_source_file))
        if (i_package == 1) {
            ceden_ckan_summary <- package_data
        } else {
            ceden_ckan_summary <- bind_rows(ceden_ckan_summary, package_data)
        }
    }
    
    View(ceden_ckan_summary)
    View(ceden_ckan_summary %>% filter(format == 'CSV')) # csv's only
    
    # complete uploads
        sum(ceden_ckan_summary$datastore_active == TRUE & ceden_ckan_summary$datastore_contains_all_records_of_source_file == TRUE)
    # incomplete uploads
        sum(ceden_ckan_summary$datastore_active == TRUE & ceden_ckan_summary$datastore_contains_all_records_of_source_file == FALSE)

        