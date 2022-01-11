# load packages -----------------------------------------------------------
library(arrow)
library(dplyr)
library(glue)
library(zip)
library(tools)



# download parquet file ---------------------------------------------------
## enter the URL of zip file containing parquet file(s) ----
### NOTE: be sure to replace the file name at the end of this link with the current version of the file name (you can also use the ckanr 
### package's resource_show() function to retrieve the current filename -- e.g., for this dataset use: 
### ckanr::resource_show(id = '8d567d61-6c07-4cd8-a2f0-3b57a9edae43', url = 'https://data.ca.gov')$url
data_url <- 'https://data.ca.gov/dataset/203e5d1f-ec9d-4d07-93aa-d8b74d3fe71f/resource/8d567d61-6c07-4cd8-a2f0-3b57a9edae43/download/esmr-analytical-export_years-2006-2021_parquet_2021-11-24.zip'

## download zip file to temp directory ----
zip_file_name <- basename(data_url)
directory_name <- file_path_sans_ext(zip_file_name)

### create temp directory 
temp_dir <- tempdir()

### download to temporary directory
download.file(url = data_url, 
              destfile = file.path(temp_dir, zip_file_name),
              mode = 'wb')

## unzip to working directory ----
zip::unzip(zipfile = file.path(temp_dir, zip_file_name), 
           exdir = directory_name)



# read data from parquet dataset ------------------------------------------
## NOTE: to speed queries, (when possible) filter the dataset by regional board 
## office (field name: region) and/or facility name (field name: facility_name) 
## (because the parquet file is partitioned by these two fields).

## establish connection to parquet dataset ----
con_esmr <- open_dataset(directory_name)

## read data ----
### get region names
names_regions <- con_esmr %>% 
    distinct(region) %>% 
    collect()

### get names of all facilities in a given region
names_facilities <- con_esmr %>% 
    filter(region == 'Region 1 - North Coast') %>% 
    distinct(facility_name) %>%
    collect() 

### get count of samples by location for given facility
facility_locations <- con_esmr %>% 
    filter(region == 'Region 1 - North Coast') %>% 
    filter(facility_name == 'Cloverdale City WWTP') %>% 
    count(location) %>% 
    collect()
# View(facility_locations)

### get count of samples by parameter for given facility and location
location_summary <- con_esmr %>% 
    filter(region == 'Region 1 - North Coast') %>% 
    filter(facility_name == 'Cloverdale City WWTP') %>% 
    filter(location == 'EFF-002') %>% 
    count(parameter) %>% 
    collect()
# View(location_summary)

### get summary stats for a given parameter at given location
parameter_summary <- con_esmr %>% 
    filter(region == 'Region 1 - North Coast') %>% 
    filter(facility_name == 'Cloverdale City WWTP') %>% 
    filter(location == 'EFF-002') %>%  
    filter(parameter == 'Nitrate, Total (as N)',
           units == 'mg/L') %>% 
    select(result) %>%
    collect() %>% 
    summary() %>%
    {.}

### extract all data for given facility and location
facility_all_data <- con_esmr %>% 
    filter(region == 'Region 1 - North Coast') %>% 
    filter(facility_name == 'Cloverdale City WWTP') %>% 
    filter(location == 'EFF-002') %>% 
    collect()
View(facility_all_data)
