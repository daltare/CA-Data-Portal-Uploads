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
dictionary_file <- here("data_dictionaries", "data_dictionary_conversion", "tissue", 
                        "CEDEN_Tissue_Data_Dictionary.xlsx")

## list resources to update ----
## list values are the resource IDs - this is the alphanumeric part at the end of a resource's URL
## list names can be anything you want to use to label a resource (the keys aren't actually used for the API call; they're' just used to keep track of the API responses)
resources_to_update <- list(
    'year-2024' = 'fe359a58-d785-4d45-af72-5e8b0f5428ff',
    'year-2023' = '1512aa84-f18d-4c60-89a0-50c2d1cd1d0c',
    'year-2022' = '6754e8b7-9136-44aa-b65c-bf3a8af6be77',
    'year-2021' = '02e2e832-fa46-4ecb-98e8-cdb70fe3902d',
    'year-2020' = 'a3545e8e-2ab5-46b3-86d5-72a74fcd8261',
    'year-2019' = 'edd16b08-3d9f-4375-9396-dce7cbd2f717',
    'year-2018' = '559c5523-8883-4da0-9750-f7fd3f088cfb',
    'year-2017' = 'e30e6266-5978-47f4-ae6a-94336ab224f9',
    'year-2016' = 'c7a56123-8692-4d92-93cc-aa12d7ab46c9',
    'year-2015' = '3376163c-dcda-4b76-9672-4ecfee1e1417',
    'year-2014' = '8256f15c-8500-47c3-be34-d12b45b0bbe9',
    'year-2013' = 'eb2d102a-ecdc-4cbe-acb9-c11161ac74b6',
    'year-2012' = '8e3bbc50-dd72-4cee-b926-b00f488ff10c',
    'year-2011' = '06440749-3ada-4461-959f-7ac2699faeb0',
    'year-2010' = '82dbd8ec-4d59-48b5-8e10-ce1e41bbf62a',
    'year-2009' = 'c1357d10-41cb-4d84-bd3a-34e18fa9ecdf',
    'year-2008' = 'da39833c-9d62-4307-a93e-2ae8ad2092e3',
    'year-2007' = 'f88461cf-49b2-4c5c-ba2c-d9484202bc74',
    'year-2006' = 'f3ac3204-f0a2-4561-ae18-836b8aafebe8',
    'year-2005' = '77daaca9-3f47-4c88-9d22-daf9f79e2729',
    'year-2004' = '1dc7ed28-a59b-48a7-bc81-ef9582a4efaa',
    'year-2003' = '1a21e2ac-a9d8-4e81-a6ad-aa6636d064d1',
    'year-2002' = '6a56b123-9275-4549-a625-e5aa6f2b8b57',
    'year-2001' = '47df34fd-8712-4f72-89ff-091b3e954399',
    'year-2000' = '06b35b3c-6338-44cb-b465-ba4c1863b7c5',
    'prior_to_2000' = '97786a54-1189-43e4-9244-5dcb241dfa58'
)

## get data portal API key (saved in the local environment) ----
## (it's available on data.ca.gov by going to your user profile)
portal_key <- Sys.getenv('data_portal_key') 

## get functions
source(here("data_dictionaries", "data_dictionary_conversion", "tissue", 
            "data_dictionary_API_upload_functions.R"))




# upload dictionaries -----------------------------------------------------
## Note: using `$status_code` just returns the HTTP status codes
api_response <- map(.x = resources_to_update, 
                    .f = \(id) upload_ckan_data_dictionary(resource_id = id, 
                                                           data_dictionary_file = dictionary_file, 
                                                           portal_key = portal_key)$status_code)

## print responses (should be "200" if successful)
api_response
