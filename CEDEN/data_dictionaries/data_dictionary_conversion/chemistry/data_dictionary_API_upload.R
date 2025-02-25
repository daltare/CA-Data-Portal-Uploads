# This uses the CKAN `datastore_create` API call to update the data dictionary 
# of an existing resouce on the data.ca.gov portal. This process does not impact 
# the data in that resource. For more information, see: 
# <https://stackoverflow.com/a/66698935>.
# 
# The process defined here assumes that the data dictionary information is saved 
# in an existing file (like an Excel workbook or CSV file - it's currently designed
# to accept an Excel file, and slight modifications will need to be made if using 
# it with a CSV). 
#
# Alternatively, if the data dictionary information has already been entered for 
# one resource, and you want to copy the data dictionary from that resource into 
# another resource (or multiple resources), there are two alternative methods at
# the bottom of this file that can help with that (they are commented out).



# setup -------------------------------------------------------------------

## load packages ----
library(tidyverse)
library(readxl)
library(here)
library(glue)
library(janitor)
library(ckanr)
library(jsonlite)
library(httr)
library(httr2)

## get data portal API key (saved in the local environment) ----
## (it's available on data.ca.gov by going to your user profile)
portal_key <- Sys.getenv('data_portal_key') 

## define ID of resource to update ----
resource_id <- '97b8bb60-8e58-4c97-a07f-d51a48cd36d4' # https://data.ca.gov/dataset/surface-water-chemistry-results/resource/97b8bb60-8e58-4c97-a07f-d51a48cd36d4

    ## get data dictionary info (assumes this is in an Excel file) ----
dictionary_file <- here('data_dictionaries', 
                        'data_dictionary_conversion', 
                        'chemistry', 
                        'CEDEN_Chemistry_Data_Dictionary.xlsx')
dictionary_fields <- c('Column', 'Type', 'Label', 'Description') # has to be in order: Column, Type, Label, Description

## (optional) get the resource IDs ----
## NOTE: this is just a set of helper functions to retrieve resource IDs programmatically
# package_id <- '28d7a81d-6458-47bd-9b79-4fcbfbb88671' # chemistry
# dataset_resources <- package_show(package_id, as = 'table', url = "https://data.ca.gov/", key = Sys.getenv('data_portal_key'))
# dataset_resources <- dataset_resources$resources %>% 
#     filter(format %in% c('CSV')) %>% # filter for just the resources containing csv files
#     select(name, id)

## (optional) get data dictionary fields info ----
## NOTE: use this if you already have the data dictionary info in the correct format, 
## e.g. if the same info is already entered on the portal in a similar dataset, 
## you can retrieve it using a 'https://data.ca.gov/api/3/action/datastore_search?...' API call
# data_dict_fields_file <- (here('data_dictionaries', 
#                                'data_dictionary_conversion', 
#                                'chemistry',
#                                'chem_data_dictionary_fields_API.txt'))




# format data dictionary fields -------------------------------------------

## NOTE: this assumes all of the necessary data dictionary info is already saved 
## in a separate file, like a CSV or Excel workbook

## read dictionary info ----
df_dictionary <- read_excel(dictionary_file) |> 
  clean_names() |> 
  select(all_of(tolower(dictionary_fields))) # just keep the relevant fields

## reformat to nested structure ----
df_dictionary_format <- df_dictionary |> 
  rowwise() |> 
  mutate(info = tibble('label' = label,
                       'notes' = description,
                       'type_override' = type)) |> 
  ungroup() |> 
  select(id = column,
         type,
         info)

## convert to JSON ----
json_dictionary <- df_dictionary_format |> 
  toJSON()



# create API call ---------------------------------------------------------

## create base request ----
req <- request("https://data.ca.gov/api/3/action/datastore_create")

## add headers ----
req <- req |> 
  req_headers("Authorization" = portal_key,
              "Content-Type" = "application/json")

## create and add request body (with field info) ----
request_body <- glue('{{"resource_id": "{resource_id}", "force": "True", "fields": {json_dictionary} }}')

req <- req |>
  req_body_raw(request_body)


## send API request ----
req |> req_dry_run() # test
resp <- req_perform(req) # execute
resp # print result



# Alternative 1 - Directly Get Dictionary Info From Existing Portal Resource -----------

# ## get fields from existing resource ----
# ### define ID of the existing resource whose dictionary will be copied
# resource_id_reference <- "9dcf551f-452d-4257-b857-30fbcc883a03"
# 
# ### create query to retrieve dictionary info
# query_url <- glue("https://data.ca.gov/api/3/action/datastore_search?resource_id={resource_id_reference}&limit=0")
# 
# ## retrieve dictionary from portal ----
# ## NOTE: use either one of the methods below - they do the same thing (keeping them for reference)
# 
# ### method 1 - httr ----
# url_encoded <- URLencode(query_url)
# query_response <- GET(url_encoded)
# query_char <- rawToChar(query_response$content)
# query_content <- fromJSON(query_char)
# resource_records <- query_content$result$records
# resource_fields <- query_content$result$fields
# resource_fields_json <- toJSON(resource_fields)
# # resource_fields_json # view
# 
# 
# ### method 2 - httr2 ----
# req_search <- request(query_url)
# resp_search <- req_perform(req_search)
# resp_search_result <- resp_search |> resp_body_json()
# resp_fields <- resp_search_result$result$fields
# resource_fields_json <- jsonlite::toJSON(resp_fields) |> str_remove_all('\\[|\\]')
# resource_fields_json <- glue("[{resource_fields_json}]") 
# # resource_fields_json # view
# 
# 
# ## create base request ----
# req <- request("https://data.ca.gov/api/3/action/datastore_create")
# 
# ## add headers ----
# req <- req |> 
#     req_headers("Authorization" = portal_key,
#                 "Content-Type" = "application/json")
# 
# ## create and add request body (with field info) ----
# request_body <- glue('{{"resource_id": "{resource_id}", "force": "True", "fields": {resource_fields_json} }}')
# 
# req <- req |>
#     req_body_raw(request_body)
# 
# ## send request ----
# req |> req_dry_run() # test
# resp <- req_perform(req) # execute 




# Alternative 2 - Use Saved Info From Existing Portal Resource --------------------

# ## assumes the formatted data dictionary is saved in a separate file, referred to 
# ## as the `data_dict_fields_file` variable below
# 
# ## create base request ----
# req <- request("https://data.ca.gov/api/3/action/datastore_create")
# 
# ## add headers ----
# req <- req |> 
#     req_headers("Authorization" = portal_key,
#                 "Content-Type" = "application/json")
# 
# ## create and add request body (with field info) ----
# chem_fields <- read_file(data_dict_fields_file)
# request_body <- glue('{{"resource_id": "{resource_id}", "force": "True", "fields": {glue("{chem_fields}")} }}')
# 
# req <- req |>
#     req_body_raw(request_body)
# 
# ## send request ----
# req |> req_dry_run() # test
# resp <- req_perform(req) # execute 

