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
library(here)



# Enter variables:
# User Input
# dictionary_filename <- readline(prompt="Enter the filename of the data dictionary to upload: ")
# dictionary_fields <- c('column', 'type', 'label', 'description') # has to be in order: Column, Type, Label, Description
# dataset_name <- readline(prompt="Enter the name of the dataset on the open data portal: ")
# data_resource_id <- readline(prompt="Enter the ID of the resource on the open data portal (from the resource's URL): ")

dictionary_filename <- 'water-rights_master-flat-file_data-dictionary_tool.xlsx'
dictionary_fields <- c('column', 'type', 'label', 'description_combined') # has to be in order: Column, Type, Label, Description
dataset_name <- 'water-rights'
data_resource_id <- '151c067a-088b-42a2-b6ad-99d84b48fb36'




# STEP 1: Get the dictionary info ----
# get the info to fill out the data dictionary 
df_dictionary <- read_excel(here('data-dictionary', 
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
# Note - for more information / examples on how the RSelenium package works, see:
# https://stackoverflow.com/questions/35504731/specify-download-folder-in-rselenium        
# https://cran.r-project.org/web/packages/RSelenium/vignettes/RSelenium-basics.html
# https://stackoverflow.com/questions/32123248/submitting-form-from-r-to-mixed-html-and-javascript
# https://github.com/ropensci/RSelenium/issues/121


# Set up RSelenium 
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
    # }
}

# click the save button
webElem <- remDr$findElement(using = 'css selector', value = 'button.btn.btn-primary')
webElem$clickElement()



# close the server
remDr$close()
# rsD$server$stop() # from the old method
rm(list = c('remDr'))#'eCaps', , 'SMARTS_url', 'rsD'))
gc()   
shell.exec(file = here('Stop.bat')) # this closes the java window
