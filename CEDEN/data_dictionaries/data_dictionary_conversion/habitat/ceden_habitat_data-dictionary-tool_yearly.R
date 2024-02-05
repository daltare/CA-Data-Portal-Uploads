# Notes:
# 1. The dictionary file should be an excel file with the header names 'column', 'label', 'type', and eithter 'description' or 'description_combined' (it may also have other colums as well - doesn't matter)
# 2. The order of the fields listed in the dictionary MUST match the order of the columns in the dataset
# 3. Make sure the fields defined as numeric or timestamp in the dictionary are correctly formatted in the dataset (missing numeric values must be 'NaN', dates must be in ISO format and missing dates should be an empty text string i.e. '')
# 4. Put the dictionary file in the same location as this script file
# 5. Enter your data.ca.gov portal username in the environment variables for you account, in a variable called 'portal_username'
# 6. Enter your data.ca.gov portal password in the environment variables for you account, in a variable called 'portal_password'
# 7. Note that the 'type' field doesn't update until the datastore is updated (go to 'Manage', 'Data Store', click 'Upload to DataStore')



# load packages
library(tidyverse)
library(RSelenium)
library(wdman)
library(methods) # it seems that this needs to be called explicitly to avoid an error for some reason
library(XML)
library(dplyr)
library(janitor)
library(readr)
library(lubridate)
library(readxl)
library(ckanr)
library(pingr)
library(binman)   
library(here)



# Enter variables:
# User Input
# dictionary_filename <- readline(prompt="Enter the filename of the data dictionary to upload: ")
# dictionary_fields <- c('column', 'type', 'label', 'description') # has to be in order: Column, Type, Label, Description
# dataset_name <- readline(prompt="Enter the name of the dataset on the open data portal: ")
# data_resource_id <- readline(prompt="Enter the ID of the resource on the open data portal (from the resource's URL): ")


# Habitat: Yearly
dictionary_filename <- 'CEDEN_Habitat_Data_Dictionary.xlsx'
dictionary_fields <- c('column', 'type', 'label', 'description') # has to be in order: Column, Type, Label, Description
dataset_name <- 'surface-water-habitat-results'

# get the resource IDs
package_id <- 'f5edfd1b-a9b3-48eb-a33e-9c246ab85adf' # habitat
dataset_resources <- package_show(package_id, as = 'table', url = "https://data.ca.gov/", key = Sys.getenv('data_portal_key'))
dataset_resources <- dataset_resources$resources %>% 
    filter(format %in% c('CSV')) %>% # filter for just the resources containing csv files
    select(name, id)
data_resource_id_list <-  list(#'Pre-2000' = 'a3dcc442-e722-495f-ad59-c704ae934848',
    # '2000' = 'b3dba1ee-6ada-42d5-9679-1a10b44630bc',
    # '2001' = 'ea8b0171-e226-4e80-991d-50752abea734',
    # '2002' = 'a9d8302d-0d37-4cf3-bbeb-386f6bd948a6',
    # '2003' = '899f3ebc-538b-428e-8f1f-d591445a847c',
    # '2004' = 'e5132397-69a5-46fb-b24a-cd3b7a1fe53a',
    # '2005' = '1609e7ab-d913-4d24-a582-9ca7e8e82233',
    # '2006' = '88b33d5b-5428-41e2-b77b-6cb46ca5d1e4',
    # '2007' = '1659a2b4-21e5-4fc4-a9a4-a614f0321c05',
    # '2008' = 'ce211c51-05a2-4a7c-be18-298099a0dcd2',
    # '2009' = 'd025552d-de5c-4f8a-b2b5-a9de9e9c86c3',
    # '2010' = '2a8b956c-38fa-4a15-aaf9-cb0fcaf915f3',
    # '2011' = '2fa6d874-1d29-478a-a5dc-0c2d31230705',
    # '2012' = '78d44ee3-65af-4c83-b75e-8a82b8a1db88',
    # '2013' = '3be276c3-9966-48de-b53a-9a98d9006cdb',
    # '2014' = '082a7665-8f54-4e4f-9d24-cc3506bb8f3e',
    # '2015' = '115c55e3-40af-4734-877f-e197fdae6737',
    # '2016' = '01e35239-6936-4699-b9db-fda4751be6e9',
    # '2017' = 'f7a33584-510f-46f8-a314-625f744ecbdd',
    # '2018' = 'd814ca0c-ace1-4cc1-a80f-d63f138e2f61',
    # '2019' = 'c0f230c5-3f51-4a7a-a3db-5eb8692654aa',
    # '2020' = 'bd37df2e-e6a4-4c2b-b01c-ce7840cc03de', 
    # '2021' = 'c82a3e83-a99b-49d8-873b-a39640b063fc', 
    # '2022' = '0fcdfad7-6588-41fc-9040-282bac2147bf',
    # '2023' = '1f6b0641-3aac-48b2-b12f-fa2d4966adfd',
    '2024' = 'a7bf7ff5-930e-417a-bc3e-1e1794cd2513')



# STEP 1: Get the dictionary info ----
# get the info to fill out the data dictionary 
df_dictionary <- read_excel(here('data_dictionaries', 'data_dictionary_conversion', 'habitat', 
                                 dictionary_filename)) %>% 
    clean_names() %>% 
    select(all_of(dictionary_fields))
# df_dictionary <- df_dictionary %>% 
#     mutate(type = tolower(type)) %>% 
#     mutate(column = tolower(column))
# check the fields defined as numeric and timestamp
# z_numeric_fields <- df_dictionary %>% filter(type == 'numeric') %>% select(column)
# identical(z_numeric_fields$column, fields_numeric) # should be TRUE
# z_timestamp_fields <- df_dictionary %>% filter(type == 'timestamp') %>% select(column)
# identical(z_timestamp_fields$column, fields_dates) # should be TRUE



# STEP 2: Set up the methodology to automate data entry, using RSelenium (use the Chrome browser in this script) ----
source(here('start_selenium.R'))



# STEP 3: Enter the data ----
# get portal username and password
portal_username <- Sys.getenv('portal_username') 
portal_password <- Sys.getenv('portal_password')

# Navigate to the data.ca.gov login page and log in
login_url <- 'https://data.ca.gov/user/login'
remDr$navigate(login_url)
webElem <- remDr$findElement(using = 'id', value = 'field-login')
webElem$sendKeysToElement(list(portal_username))
webElem <- remDr$findElement(using = 'id', value = 'field-password')
webElem$sendKeysToElement(list(portal_password))
webElem <- remDr$findElement(using = 'css selector', value = 'button.btn.btn-primary')
webElem$clickElement()

# loop through the resources
for (id_number in seq_along(names(data_resource_id_list))) {
    data_resource_id <- data_resource_id_list[[id_number]]
    
    # Navigate to the data dictionary editor page
    dictionary_url <- paste0('https://data.ca.gov/dataset/', dataset_name, '/dictionary/', data_resource_id)
    remDr$navigate(dictionary_url)
    
    # loop through all of the fields defined in the dictionary and enter into the data dictionary interface on the portal
    for (i in seq(nrow(df_dictionary))){
        # enter the field type
        webElem <- remDr$findElement(using = 'id', value = paste0('info__', i, '__type_override'))
        webElem$sendKeysToElement(list(df_dictionary[[i, dictionary_fields[2]]]))
        # enter the label
        webElem <- remDr$findElement(using = 'id', value = paste0('field-f', i, 'label'))
        webElem$clearElement()
        webElem$sendKeysToElement(list(df_dictionary[[i, dictionary_fields[3]]]))
        # enter the description
        webElem <- remDr$findElement(using = 'id', value = paste0('field-d', i, 'notes'))
        webElem$clearElement()
        webElem$sendKeysToElement(list(df_dictionary[[i, dictionary_fields[4]]]))
    }
    
    # click the save button
    webElem <- remDr$findElement(using = 'css selector', value = 'button.btn.btn-primary')
    webElem$clickElement()
}



# close the server
remDr$close()
# rsD$server$stop() # from the old method
rm(list = c('remDr'))#'eCaps', , 'SMARTS_url', 'rsD'))
gc()   
shell.exec(file = here('Stop.bat')) # this closes the java window
