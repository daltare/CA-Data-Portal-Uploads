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

# Chemistry - all years
dictionary_filename <- 'CEDEN_Chemistry_Data_Dictionary.xlsx'
dictionary_fields <- c('column', 'type', 'label', 'description') # has to be in order: Column, Type, Label, Description
dataset_name <- 'surface-water-chemistry-results'

# get the resource IDs
package_id <- '28d7a81d-6458-47bd-9b79-4fcbfbb88671' # chemistry
dataset_resources <- package_show(package_id, as = 'table', url = "https://data.ca.gov/", key = Sys.getenv('data_portal_key'))
dataset_resources <- dataset_resources$resources %>% 
    filter(format %in% c('CSV')) %>% # filter for just the resources containing csv files
    select(name, id)

data_resource_id_list <-  list('year-2023' = '6f9dd0e2-4e16-46c2-bed1-fa844d92df3c'#,
                               # 'year-2022' = '5d7175c8-dfc6-4c43-b78a-c5108a61c053',
                               #'2021' = 'dde19a95-504b-48d7-8f3e-8af3d484009f',
                               # '2020' = '2eba14fa-2678-4d54-ad8b-f60784c1b234', 
                               # '2019' = '6cf99106-f45f-4c17-80af-b91603f391d9',
                               # '2018' = 'f638c764-89d5-4756-ac17-f6b20555d694',
                               # '2017' = '68787549-8a78-4eea-b5b9-ef719e65a05c', 
                               # '2016' = '42b906a2-9e30-4e44-92c9-0f94561e47fe', 
                               # '2015' = '7d9384fa-70e1-4986-81d6-438ce5565be6',
                               # '2014' = '7abfde16-61b6-425d-9c57-d6bd70700603', 
                               # '2013' = '341627e6-a483-4e9e-9a85-9f73b6ddbbba',
                               # '2012' = 'f9dd0348-85d5-4945-aa62-c7c9ad4cf6fd', 
                               # '2011' = '4d01a693-2a22-466a-a60b-3d6f236326ff', 
                               # '2010' = '572bf4d2-e83d-490a-9aa5-c1d574e36ae0', 
                               # '2009' = '5b136831-8870-46f2-8f72-fe79c23d7118',
                               # '2008' = 'c587a47f-ac28-4f77-b85e-837939276a28',
                               # '2007' = '13e64899-df32-461c-bec1-a4e72fcbbcfa',
                               # '2006' = 'a31a7864-06b9-4a81-92ba-d8912834ca1d',
                               # '2005' = '9538cbfa-f8be-4445-97dc-b931579bb927', 
                               # '2004' = 'c962f46d-6a7b-4618-90ec-3c8522836f28',
                               # '2003' = 'd3f59df4-2a8d-4b40-b90f-8147e73335d9',
                               # '2002' = '00c4ca34-064f-4526-8276-57533a1a36d9',
                               # '2001' = 'cec6768c-99d3-45bf-9e56-d62561e9939e',
                               # '2000' = '99402c9c-5175-47ca-8fce-cb6c5ecc8be6',
                               # 'prior_to_2000' = '158c8ca1-b02f-4665-99d6-2c1c15b6de5a'
)



# STEP 1: Get the dictionary info ----
# get the info to fill out the data dictionary 
df_dictionary <- read_excel(here('data_dictionaries', 'data_dictionary_conversion', 'chemistry', 
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
