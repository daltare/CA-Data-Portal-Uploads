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
dictionary_file <- here("esmr-data-dictionary-tool", 
                        "eSMR_Data_Dictionary_Template.xlsx")

## list resources to update ----
## list values are the resource IDs - this is the alphanumeric part at the end of a resource's URL
## list names can be anything you want to use to label a resource (the keys aren't actually used for the API call; they're' just used to keep track of the API responses)
resources_to_update <- list('2025' = '176a58bf-6f5d-4e3f-9ed9-592a509870eb'#, 
                            # '2024' = '7adb8aea-62fb-412f-9e67-d13b0729222f',
                            # '2023' = '65eb7023-86b6-4960-b714-5f6574d43556',
                            # '2022' = '8c6296f7-e226-42b7-9605-235cd33cdee2',
                            # '2021' = '28d3a164-7cec-4baf-9b11-7a9322544cd6',
                            # '2020' = '4fa56f3f-7dca-4dbd-bec4-fe53d5823905',
                            # '2019' = '2eaa2d55-9024-431e-b902-9676db949174',
                            # '2018' = 'bb3b3d85-44eb-4813-bbf9-ea3a0e623bb7',
                            # '2017' = '44d1f39c-f21b-4060-8225-c175eaea129d',
                            # '2016' = 'aacfe728-f063-452c-9dca-63482cc994ad',
                            # '2015' = '81c399d4-f661-4808-8e6b-8e543281f1c9',
                            # '2014' = 'c0f64b3f-d921-4eb9-aa95-af1827e5033e',
                            # '2013' = '8fefc243-9131-457f-b180-144654c1f481',
                            # '2012' = '67fe1c01-1c1c-416a-92e1-ee8437db615a',
                            # '2011' = 'c495ca93-6dbe-4b23-9d17-797127c28914',
                            # '2010' = '4eb833b3-f8e9-42e0-800e-2b1fe1e25b9c',
                            # '2009' = '3607ae5c-d479-4520-a2d6-3112cf92f32f',
                            # '2008' = 'c0e3c8be-1494-4833-b56d-f87707c9492c',
                            # '2007' = '7b99f591-23ac-4345-b645-9adfaf5873f9',
                            # '2006' = '763e2c90-7b7d-412e-bbb5-1f5327a5f84e'
)

## get data portal API key (saved in the local environment) ----
## (it's available on data.ca.gov by going to your user profile)
portal_key <- Sys.getenv('data_portal_key') 

## get functions
source(here("esmr-data-dictionary-tool", 
            "data_dictionary_API_upload_functions.R"))




# upload dictionaries -----------------------------------------------------
## Note: using `$status_code` just returns the HTTP status codes
api_response <- map(.x = resources_to_update, 
                    .f = \(id) upload_ckan_data_dictionary(resource_id = id, 
                                                           data_dictionary_file = dictionary_file, 
                                                           portal_key = portal_key)$status_code)

## print responses (should be "200" if successful)
api_response
