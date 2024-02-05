# Notes:
# 1. The dictionary file should be an excel file with the header names 'column', 'label', 'type', and eithter 'description' or 'description_combined' (it may also have other colums as well - doesn't matter)
# 2. The order of the fields listed in the dictionary MUST match the order of the columns in the dataset
# 3. Make sure the fields defined as numeric or timestamp in the dictionary are correctly formatted in the dataset (missing numeric values must be 'NaN', dates must be in ISO format and missing dates should be an empty text string i.e. '')
# 4. Put the dictionary file in the same location as this script file
# 5. Enter your data.ca.gov portal username in the environment variables for you account, in a variable called 'portal_username'
# 6. Enter your data.ca.gov portal password in the environment variables for you account, in a variable called 'portal_password'
# 7. Note that the 'type' field doesn't update until the datastore is updated (go to 'Manage', 'Data Store', click 'Upload to DataStore')


# load packages
library(RSelenium)
library(methods) # it seems that this needs to be called explicitly to avoid an error for some reason
library(XML)
library(dplyr)
library(janitor)
library(readr)
library(lubridate)
library(readxl)
library(ckanr)
library(binman)
library(wdman)
library(stringr)
library(magrittr)
library(here)



# Enter variables:
# User Input
# dictionary_filename <- readline(prompt="Enter the filename of the data dictionary to upload: ")
# dictionary_fields <- c('column', 'type', 'label', 'description') # has to be in order: Column, Type, Label, Description
# dataset_name <- readline(prompt="Enter the name of the dataset on the open data portal: ")
# data_resource_id <- readline(prompt="Enter the ID of the resource on the open data portal (from the resource's URL): ")

# eSMR - all years
dictionary_filename <- 'eSMR_Data_Dictionary_Template.xlsx'
dictionary_fields <- c('column', 'type', 'label', 'description') # has to be in order: Column, Type, Label, Description
dataset_name <- 'water-quality-effluent-electronic-self-monitoring-report-esmr-data'

# get the resource IDs
# package_id <- '28d7a81d-6458-47bd-9b79-4fcbfbb88671' # chemistry
# dataset_resources <- package_show(package_id, as = 'table', url = "https://data.ca.gov/", key = Sys.getenv('data_portal_key'))
# dataset_resources <- dataset_resources$resources %>% 
#     filter(format %in% c('CSV')) %>% # filter for just the resources containing csv files
#     select(name, id)

data_resource_id_list <-  list('2024' = '7adb8aea-62fb-412f-9e67-d13b0729222f'#,
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



# STEP 1: Get the dictionary info ----
# get the info to fill out the data dictionary 
df_dictionary <- read_excel(here('esmr-data-dictionary-tool', 
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
