# Uses the CKAN `datastore_create` API call to update the data dictionary 
# of an existing resouce on the data.ca.gov portal. Requires that the data 
# dictionary information is saved in an existing Excel file. 

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
dictionary_file <- here("CEDEN_Chemistry_Data_Dictionary.xlsx")

## list resources to update ----
## list values are the resource IDs - this is the alphanumeric part at the end of a resource's URL
## list names can be anything you want to use to label a resource (the keys aren't actually used for the API call; they're' just used to keep track of the API responses)
resources_to_update <- list(
  'year-2025' = '97b8bb60-8e58-4c97-a07f-d51a48cd36d4',
  'year-2024' = '9dcf551f-452d-4257-b857-30fbcc883a03',
  'year-2023' = '6f9dd0e2-4e16-46c2-bed1-fa844d92df3c',
  'year-2022' = '5d7175c8-dfc6-4c43-b78a-c5108a61c053',
  'year-2021' = 'dde19a95-504b-48d7-8f3e-8af3d484009f',
  'year-2020' = '2eba14fa-2678-4d54-ad8b-f60784c1b234',
  'year-2019' = '6cf99106-f45f-4c17-80af-b91603f391d9',
  'year-2018' = 'f638c764-89d5-4756-ac17-f6b20555d694',
  'year-2017' = '68787549-8a78-4eea-b5b9-ef719e65a05c',
  'year-2016' = '42b906a2-9e30-4e44-92c9-0f94561e47fe',
  'year-2015' = '7d9384fa-70e1-4986-81d6-438ce5565be6',
  'year-2014' = '7abfde16-61b6-425d-9c57-d6bd70700603',
  'year-2013' = '341627e6-a483-4e9e-9a85-9f73b6ddbbba',
  'year-2012' = 'f9dd0348-85d5-4945-aa62-c7c9ad4cf6fd',
  'year-2011' = '4d01a693-2a22-466a-a60b-3d6f236326ff',
  'year-2010' = '572bf4d2-e83d-490a-9aa5-c1d574e36ae0',
  'year-2009' = '5b136831-8870-46f2-8f72-fe79c23d7118',
  'year-2008' = 'c587a47f-ac28-4f77-b85e-837939276a28',
  'year-2007' = '13e64899-df32-461c-bec1-a4e72fcbbcfa',
  'year-2006' = 'a31a7864-06b9-4a81-92ba-d8912834ca1d',
  'year-2005' = '9538cbfa-f8be-4445-97dc-b931579bb927',
  'year-2004' = 'c962f46d-6a7b-4618-90ec-3c8522836f28',
  'year-2003' = 'd3f59df4-2a8d-4b40-b90f-8147e73335d9',
  'year-2002' = '00c4ca34-064f-4526-8276-57533a1a36d9',
  'year-2001' = 'cec6768c-99d3-45bf-9e56-d62561e9939e',
  'year-2000' = '99402c9c-5175-47ca-8fce-cb6c5ecc8be6',
  'prior_to_2000' = '158c8ca1-b02f-4665-99d6-2c1c15b6de5a'
)

## get data portal API key (saved in the local environment) ----
## (it's available on data.ca.gov by going to your user profile)
portal_key <- Sys.getenv('data_portal_key') 

## get functions
source(here("data_dictionary_API_upload_functions.R"))




# upload dictionaries -----------------------------------------------------
## Note: using `$status_code` just returns the HTTP status codes
api_response <- map(.x = resources_to_update, 
                    .f = \(id) upload_ckan_data_dictionary(resource_id = id, 
                                                           data_dictionary_file = dictionary_file, 
                                                           portal_key = portal_key)$status_code)

## print responses (should be "200" if successful)
api_response
