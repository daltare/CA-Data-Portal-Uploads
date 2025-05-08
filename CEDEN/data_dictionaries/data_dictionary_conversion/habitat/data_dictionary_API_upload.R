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
dictionary_file <- here("data_dictionaries", "data_dictionary_conversion", "habitat", 
                        "CEDEN_Habitat_Data_Dictionary.xlsx")

## list resources to update ----
## list values are the resource IDs - this is the alphanumeric part at the end of a resource's URL
## list names can be anything you want to use to label a resource (the keys aren't actually used for the API call; they're' just used to keep track of the API responses)
resources_to_update <- list(
    'year-2025' = '3e02cc4d-7a91-4348-9537-7597b0702f57'#,
    # 'year-2024' = 'a7bf7ff5-930e-417a-bc3e-1e1794cd2513',
    # 'year-2023' = '1f6b0641-3aac-48b2-b12f-fa2d4966adfd',
    # 'year-2022' = '0fcdfad7-6588-41fc-9040-282bac2147bf',
    # 'year-2021' = 'c82a3e83-a99b-49d8-873b-a39640b063fc',
    # 'year-2020' = 'bd37df2e-e6a4-4c2b-b01c-ce7840cc03de',
    # 'year-2019' = 'c0f230c5-3f51-4a7a-a3db-5eb8692654aa',
    # 'year-2018' = 'd814ca0c-ace1-4cc1-a80f-d63f138e2f61',
    # 'year-2017' = 'f7a33584-510f-46f8-a314-625f744ecbdd',
    # 'year-2016' = '01e35239-6936-4699-b9db-fda4751be6e9',
    # 'year-2015' = '115c55e3-40af-4734-877f-e197fdae6737',
    # 'year-2014' = '082a7665-8f54-4e4f-9d24-cc3506bb8f3e',
    # 'year-2013' = '3be276c3-9966-48de-b53a-9a98d9006cdb',
    # 'year-2012' = '78d44ee3-65af-4c83-b75e-8a82b8a1db88',
    # 'year-2011' = '2fa6d874-1d29-478a-a5dc-0c2d31230705',
    # 'year-2010' = '2a8b956c-38fa-4a15-aaf9-cb0fcaf915f3',
    # 'year-2009' = 'd025552d-de5c-4f8a-b2b5-a9de9e9c86c3',
    # 'year-2008' = 'ce211c51-05a2-4a7c-be18-298099a0dcd2',
    # 'year-2007' = '1659a2b4-21e5-4fc4-a9a4-a614f0321c05',
    # 'year-2006' = '88b33d5b-5428-41e2-b77b-6cb46ca5d1e4',
    # 'year-2005' = '1609e7ab-d913-4d24-a582-9ca7e8e82233',
    # 'year-2004' = 'e5132397-69a5-46fb-b24a-cd3b7a1fe53a',
    # 'year-2003' = '899f3ebc-538b-428e-8f1f-d591445a847c',
    # 'year-2002' = 'a9d8302d-0d37-4cf3-bbeb-386f6bd948a6',
    # 'year-2001' = 'ea8b0171-e226-4e80-991d-50752abea734',
    # 'year-2000' = 'b3dba1ee-6ada-42d5-9679-1a10b44630bc',
    # 'prior_to_2000' = 'a3dcc442-e722-495f-ad59-c704ae934848'
)

## get data portal API key (saved in the local environment) ----
## (it's available on data.ca.gov by going to your user profile)
portal_key <- Sys.getenv('data_portal_key') 

## get functions
source(here("data_dictionaries", "data_dictionary_conversion", "habitat", 
            "data_dictionary_API_upload_functions.R"))




# upload dictionaries -----------------------------------------------------
## Note: using `$status_code` just returns the HTTP status codes
api_response <- map(.x = resources_to_update, 
                    .f = \(id) upload_ckan_data_dictionary(resource_id = id, 
                                                           data_dictionary_file = dictionary_file, 
                                                           portal_key = portal_key)$status_code)

## print responses (should be "200" if successful)
api_response
