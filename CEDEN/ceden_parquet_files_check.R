# check parquet files generated for CEDEN data (Water Chemistry, Habitat, Tissue, Toxicity, Benthic Macroinvertebrates)


# setup -------------------------------------------------------------------
library(tidyverse)
library(arrow)
library(tictoc)
library(glue)
library(zip)
library(tools)
library(here)


# connect to dataset ------------------------------------------------------

## parquet file paths ----
file_type <- 'Habitat'
file_date <- '2024-08-01'
parquet_dir <- glue('C:/Users/daltare/Documents/ca_data_portal_temp/CEDEN/{file_date}/parquet_datasets/{file_type}Data_Parquet_{file_date}.zip')

## unzip file to temporary directory ----
zip_file_name <- basename(parquet_dir)
zip_directory_name <- file_path_sans_ext(zip_file_name)

### create temporary directory ----
temp_dir <- tempdir()

### unzip (to temporary directory) ----
zip::unzip(zipfile = parquet_dir, 
           exdir = file.path(temp_dir, zip_directory_name))

## create a connection to the dataset (with Arrow) ----
ds_con <- open_dataset(file.path(temp_dir, zip_directory_name))


# query data from parquet dataset -----------------------------------------

## view a list of all fields and their associated data types ----
ds_con 

## query ----
test_analytes <- ds_con %>% 
    count(Analyte) %>% 
    collect()
View(test_analytes)

### CSCI scores ----
df_csci <- ds_con %>% 
    filter(Analyte == 'CSCI') %>% 
    collect()
#### count CSCI records by year (of sample date) ----
df_csci %>% 
    mutate(sample_year = year(SampleDate)) %>% 
    count(sample_year) %>% 
    View()
