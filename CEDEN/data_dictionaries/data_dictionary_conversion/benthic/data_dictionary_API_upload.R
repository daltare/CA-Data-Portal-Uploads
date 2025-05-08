# Use the CKAN `datastore_create` API call to update the data dictionary 
# of an existing resource on the data.ca.gov portal. Requires that the data 
# dictionary information is saved in an existing Excel file. For more 
# information about how the information in the data dictionary file should be 
# structured, see the documentation for the `upload_ckan_data_dictionary` 
# function.

# (Note: this process does not impact the data in that resource. For more 
# information, see: <https://stackoverflow.com/a/66698935>.)



# setup -------------------------------------------------------------------

## load packages ----
library(tidyverse)
library(here)

## packages used by functions - shouldn't need to load
# library(readxl)
# library(glue)
# library(janitor)
# library(jsonlite)
# library(httr2)


## enter name of data dictionary file to use ----
## (see the documentation for the `upload_ckan_data_dictionary` function for specifications on how this file should be structured)
dictionary_file <- here("data_dictionaries", "data_dictionary_conversion", "benthic", 
                        "CEDEN_Benthic_Data_Dictionary.xlsx")

## list resources to update ----
## list values are the resource IDs - this is the alphanumeric part at the end of a resource's URL
## list names can be anything you want to use to label a resource (the keys aren't actually used for the API call; they're' just used to keep track of the API responses)
resources_to_update <- list(
    'all_years' = '3dfee140-47d5-4e29-99ae-16b9b12a404f'
)

## get data portal API key (saved in the local environment) ----
## (it's available on data.ca.gov by going to your user profile)
portal_key <- Sys.getenv('data_portal_key') 

## get functions
source(here("data_dictionaries", "data_dictionary_conversion", "benthic", 
            "data_dictionary_API_upload_functions.R"))




# upload dictionaries -----------------------------------------------------
## Note: using `$status_code` just returns the HTTP status codes
api_response <- map(.x = resources_to_update, 
                    .f = \(id) upload_ckan_data_dictionary(resource_id = id, 
                                                           data_dictionary_file = dictionary_file, 
                                                           portal_key = portal_key)$status_code)

## print responses (should be "200" if successful)
api_response
