# NOTE: To schedule this script to run automatically, go to 'Addins' and 'Schedule R scripts on...', then select 
# the file that calls this script ("C:\\David\\Open_Data_Project\\__CA_DataPortal\\_Call_Scripts\\Call_SurfWater_Script.R.R")
# and set the time/date option (make sure the date format is %m/%d/%Y)


# load libraries ----
library(tidyverse)
library(janitor)
library(readr)
library(ckanr)
library(dplyr)
library(lubridate)
library(tidylog)
library(here)
library(glue)


# setup ----
# define direct links to the data
geotracker_link <- 'https://geotracker.waterboards.ca.gov/data_download/GeoTrackerDownload.zip' # see: https://geotracker.waterboards.ca.gov/datadownload

# define data portal resource ID
resourceID <- 'dc042197-e538-4a8b-9266-9c288aa72dcd' # https://data.ca.gov/dataset/ground-water-water-quality-regulatory-information/resource/dc042197-e538-4a8b-9266-9c288aa72dcd


## Alternate Method ----
### just get file and upload to portal (without reading into R)
# if (file.exists(here('sites.txt'))) {
#     unlink(here('sites.txt'))
# }
# temp <- tempfile()
# download.file(url = geotracker_link, destfile = temp, method = 'curl')
# unzip(zipfile = temp, files = 'sites.txt', exdir = here(), overwrite = TRUE)
# unlink(temp)
# out_file <- here(glue('sites_{Sys.Date()}.txt'))
# file.rename(from = here('sites.txt'), out_file)


# delete old versions of dataset ----
delete_old_versions <- TRUE
filename_geotracker <- 'geotracker_sites'

if (delete_old_versions == TRUE) {
    files_list <- grep(pattern = paste0('^', filename_geotracker), 
                       x = list.files(), 
                       value = TRUE) # get a list of all of the files of this type (including the new one) (NOTE: ^ means: starts with..)
    files_to_keep <- c(paste0(filename_geotracker, '_', Sys.Date() - seq(0,14), '.csv')) # keep the files from the previous 14 days
    files_list_old <- files_list[!(files_list %in% files_to_keep)] # exclude the new file from the list of files to be deleted
    if (length(files_list_old) > 0) {
        file.remove(files_list_old)
    }
}


# get data and read into R ----
## GeoTracker sites file
temp <- tempfile()
download.file(url = geotracker_link, destfile = temp, method = 'curl')
data_geotracker <- read_tsv(unz(temp, 'sites.txt'), 
                            guess_max = 999999, 
                            quote = '')
unlink(temp)
        
        
# format dataset ----
## check for and filter out any duplicates ----
data_geotracker <- data_geotracker %>% 
    distinct()   

## clean up the names
# data_geotracker <- clean_names(data_geotracker)

## check for portal compatibility (for timestamp and numeric fields) and adjust as needed
glimpse(data_geotracker)

## date fields ----
## convert dates into a timestamp field that can be read by the portal
fields_dates <- c('STATUS_DATE', 'BEGIN_DATE')

### check
# range(as.Date(data_geotracker$STATUS_DATE), na.rm = TRUE)
# sum(is.na(data_geotracker$STATUS_DATE))
# range(data_geotracker$BEGIN_DATE, na.rm = TRUE)
# sum(is.na(data_geotracker$BEGIN_DATE))

### convert dates
for (counter in seq(length(fields_dates))) {
    # convert the date field to ISO format
    dates_iso <- ymd(data_geotracker[[fields_dates[counter]]])
    # check NAs: sum(is.na(dates_iso))
    
    # Convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
    dates_iso <- as.character(dates_iso)
    # Check: sum(is.na(dates_iso))
    
    dates_iso[is.na(dates_iso)] <- ''
    # check NAs: sum(is.na(dates_iso))
    
    # Insert the revised date field back into the dataset
    data_geotracker[,fields_dates[counter]] <- dates_iso
}

## numeric fields ----
### ensure all records are compatible with numeric format 
fields_numeric <- c('LATITUDE', 'LONGITUDE')

### convert
for (counter in seq(length(fields_numeric))) {
    data_geotracker[,fields_numeric[counter]] <- as.numeric(data_geotracker[[fields_numeric[counter]]])
}

## text fields ----
### Convert missing values in text fields to 'NA' (to avoid converting to NaN) !!!!!!!!!!!
### from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
data_geotracker <- data_geotracker %>% 
    mutate_if(is.character, ~replace(., is.na(.), 'NA'))
    # mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))


### write revised dataset as a csv file ----
out_file <- here(glue('geotracker_sites_{Sys.Date()}.csv'))
write_csv(x = data_geotracker, 
          file = out_file, 
          na = 'NaN')


# write to open data portal ----
## get the data portal API key saved in the local environment (it's available on data.ca.gov by going to your user profile)
portal_key <- Sys.getenv('data_portal_key')

## set the ckan defaults    
ckanr_setup(url = 'https://data.ca.gov/', key = portal_key)

## get resource info (just as a check)
ckan_resource_info <- resource_show(id = resourceID, as = 'table')

## write to portal
# file_upload <- ckanr::resource_update(id = resourceID, path = out_file)
        