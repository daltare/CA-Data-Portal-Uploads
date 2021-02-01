#####################################################################################
# Resources: 
    # https://gist.github.com/jthomasmock/b8a1c6e90a199cf72c6c888bd899e84e
#####################################################################################

#### SETUP #######################################################################
# load packages
library(arrow)
library(tidyverse)
library(tictoc)
library(readr)
library(data.table)
library(glue)
library(readxl)
library(zip)

# enter some information and create a parent directory
download_date <- '2021-01-27'
directory_name <- 'ceden_chemistry'
directory_name <- glue('{directory_name}_{download_date}')
dir.create(directory_name)
latest_year <- year(as.Date(download_date))


#### CREATE PARQUET FILES ########################################################
# create function for partition directories and download parquet files
    # create a list of the column types, to use when reading in the data
        df_types <- read_xlsx("C:\\David\\Open_Data_Project\\__CA_DataPortal\\CEDEN\\data_dictionary_conversion\\water_chemistry\\CEDEN_Chemistry_Data_Dictionary.xlsx")
        field_types <- df_types %>% 
            pull(type) %>% 
            str_replace(pattern = 'text', replacement = 'c') %>% 
            str_replace(pattern = 'numeric', replacement = 'n') %>% 
            str_replace(pattern = 'timestamp', replacement = 'T') %>% 
            glue_collapse() %>%  
            {.}
    
convert_data <- function(year){
    # create directory
        dir.create(file.path(directory_name, year))
 
    # read file
        df_ceden_chem <- read_csv(glue('C:\\David\\Open_Data_Project\\__CA_DataPortal\\CEDEN\\data_download\\CEDEN_Datasets\\{download_date}\\WaterChemistryData_year-{year}_{download_date}.csv'), 
                                  col_types = field_types, 
                                  na = 'NaN')
    
    # create parquet
        arrow::write_parquet(df_ceden_chem, glue('{directory_name}/{year}/data.parquet'))
}

#### create folder and parquet file for each year from 2000 to present ####
        walk(2000:latest_year, convert_data)
        rm(df_ceden_chem)

# pre-2000 data ####
    # read file
    df_ceden_chem_pre2000 <- read_csv(glue('C:\\David\\Open_Data_Project\\__CA_DataPortal\\CEDEN\\data_download\\CEDEN_Datasets\\{download_date}\\WaterChemistryData_prior_to_2000_{download_date}.csv'), 
                                      col_types = field_types, 
                                      na = 'NaN') %>% 
        mutate(sample_year = year(SampleDate))
    # get a list of years in the dataset
    list_years_pre2000 <- df_ceden_chem_pre2000 %>% 
        distinct(sample_year) %>% 
        arrange(sample_year) %>% 
        pull(sample_year)
    
    convert_data_pre2000 <- function(year){
        # create directory
        dir.create(file.path(directory_name, year))
        
        # filter for given year
        df_ceden_chem_year <- df_ceden_chem_pre2000 %>% 
            filter(sample_year == year) %>% 
            select(-sample_year)
        
        # create parquet
        arrow::write_parquet(df_ceden_chem_year, 
                             glue('{directory_name}/{year}/data.parquet'))
    }
    
    # create folder and parquet file for each year
        walk(list_years_pre2000, convert_data_pre2000)
        rm(df_ceden_chem_pre2000)

# add all of the files to a zip file, but without compression (this file can be loaded to the data portal)
    zip::zip(zipfile = glue('{directory_name}.zip'), 
             root = directory_name,
             recurse = TRUE,
             #mode = 'cherry-pick',
             # files = glue('{directory_name}/{list.files(directory_name, recursive = TRUE)}'),
             files = list.files(recursive = TRUE),
             compression_level = 0)
    # move the zip file back to the working directory
    if (file.copy(from = glue('{directory_name}/{directory_name}.zip'), to = '.')) {
        unlink(glue('{directory_name}/{directory_name}.zip'))
    }
    
    

    
#### TEST ############################################################################
# open connection as arrow
    ds_chemistry <- open_dataset(directory_name, partitioning = "year")

# pull some data
    tic()
    df_from_arrow_all <- ds_chemistry %>% 
        select(year, Analyte, Unit, Result, MDL, RL) %>%
        filter(Analyte %in% c("E. coli")) %>% 
        collect() 
    toc()
    
    df_from_arrow_all %>% count(Analyte)
    View(df_from_arrow_all %>% count(year))

# pull some data then summarize
    tic()
    df_from_arrow_all_summarize <- ds_chemistry %>% 
        select(year, Analyte, Unit, Result, MDL, RL) %>%
        filter(Analyte %in% c("E. coli")) %>% 
        # collect() %>% 
        group_by(Analyte, Unit, year) %>%
        collect() %>% 
        summarize(
            avg_result = mean(Result, na.rm = TRUE),
            max_result = max(Result, na.rm = TRUE),
            n = n()
        ) %>%
        {.}
    toc()
    df_from_arrow_all_summarize

# get number of records by year
    tic()
    df_from_arrow_all_counts <- ds_chemistry %>% 
        select(year, Analyte, Unit, Result, MDL, RL) %>%
        # filter(Analyte %in% c("E. coli")) %>% 
        collect() %>%
        count(year) %>% 
        # collect() %>% 
        # summarize(
        #     avg_result = mean(Result, na.rm = TRUE),
        #     max_result = max(Result, na.rm = TRUE),
        #     n = n()
        # ) %>%
        {.}
    toc()
    View(df_from_arrow_all_counts)
# XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX





#### Feather ###################################################################
library(feather)
yr <- 2017    
path <- glue('chem_data_{yr}.feather')

tic()
df_ceden_chem <- read_csv(glue('C:\\David\\Open_Data_Project\\__CA_DataPortal\\CEDEN\\data_download\\CEDEN_Datasets\\{download_date}\\WaterChemistryData_year-{yr}_{download_date}.csv'), 
                                  col_types = field_types, 
                                  na = 'NaN')
toc()

write_feather(df_ceden_chem, path)

tic()
df_test_feather <- read_feather(path)
toc()
