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
library(lubridate)

# enter some information and create a parent directory
download_date <- '2021-07-19'
list_datasets <- list('ceden_chemistry' = c(file_name = 'WaterChemistryData',
                                            data_dictionary = 'water_chemistry\\CEDEN_Chemistry_Data_Dictionary.xlsx'),
                      'ceden_tissue' = c(file_name = 'TissueData',
                                         data_dictionary = 'tissue\\CEDEN_Tissue_Data_Dictionary.xlsx'),
                      'ceden_habitat' = c(file_name = 'HabitatData',
                                          data_dictionary = 'habitat\\CEDEN_Habitat_Data_Dictionary.xlsx'),
                      'ceden_benthic' = c(file_name = 'BenthicData',
                                          data_dictionary = 'benthic\\CEDEN_Benthic_Data_Dictionary.xlsx'),
                      'ceden_toxicity' = c(file_name = 'ToxicityData',
                                           data_dictionary = 'toxicity\\CEDEN_Toxicity_Data_Dictionary.xlsx'))
data_dictionaries_path <- 'C:\\Users\\daltare\\OneDrive - Water Boards\\projects\\CA_data_portal\\CEDEN\\data_dictionaries\\data_dictionary_conversion'
data_files_path <- 'C:\\David\\_CA_data_portal\\CEDEN\\CEDEN_Datasets'
file_save_location <- 'C:\\David\\_CA_data_portal\\CEDEN\\parquet_datasets\\'


# XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# create function to create a parquet file for data from 2000 - present
# create parquet file for for a single year, given the year, directory name for the new file, and file name for the source data
convert_data <- function(year, directory_name, file_name) {
    source_file <- glue('{data_files_path}\\{download_date}\\{file_name}_year-{year}_{download_date}.csv')
    # check to see if source data file exists, if so create a corresponding parquet file
    if (file.exists(source_file)) {
        # create directory for the given year
        dir.create(paste0(file_save_location, directory_name, '\\', year))
        
        # read source data file
        df_ceden <- read_csv(glue('{data_files_path}\\{download_date}\\{file_name}_year-{year}_{download_date}.csv'), 
                             col_types = field_types,
                             na = 'NaN')
        
        if (file_name == 'TissueData') { # dates in the tissue dataset are formatted differently than the other datasets
            df_ceden <- df_ceden %>% 
                mutate_at(vars(contains(c('EarliestDateSampled', 'PrepPreservationDate', 
                                          'DigestExtractDate', 'AnalysisDate', 'LatestDateSampled', 
                                          'HomogonizedDate'))), mdy) %>% # 'CompositeSampleDate', 
                mutate(SampleDate = ymd(SampleDate))
        }
        
        # create parquet file
        arrow::write_parquet(df_ceden, 
                             paste0(file_save_location, directory_name, '\\', year, '\\', 'data.parquet'))
    }
}

# XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# create function to create a parquet file for each year with data prior to 2000
# create parquet file for for a single year, given the year, directory name for the new file, and data frame with source data
    convert_data_pre2000 <- function(year, directory_name, source_data){
        # create directory for the given year
        dir.create(paste0(file_save_location, directory_name, '\\', year))
        
        # filter source data for given year
        df_ceden_year <- source_data %>% 
            filter(sample_year == year) %>% 
            select(-sample_year)
        
        # create parquet
        arrow::write_parquet(df_ceden_year, 
                             paste0(file_save_location, directory_name, '\\', year, '\\', 'data.parquet'))
    }

    
# XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# loop through all of the datasets and create parquet files
for (i in seq_along(names(list_datasets))) {
    directory_name <- names(list_datasets[i])
    directory_name <- glue('{directory_name}_{download_date}')
    # create a directory for the given data type
    dir.create(paste0(file_save_location, directory_name))
    latest_year <- year(as.Date(download_date))
    file_name <- list_datasets[[i]][['file_name']]
    
    # create a list of the column types, to use when reading in the data
    df_types <- read_xlsx(glue('{data_dictionaries_path}\\{list_datasets[[i]][["data_dictionary"]]}')) #water_chemistry\\CEDEN_Chemistry_Data_Dictionary.xlsx")
    field_types <- df_types %>% 
        pull(type) %>% 
        str_replace(pattern = 'text', replacement = 'c') %>% 
        str_replace(pattern = 'numeric', replacement = 'n') %>% 
        str_replace(pattern = 'timestamp', replacement = 'T') %>% 
        glue_collapse() %>%  
        {.}
    if (file_name == 'TissueData') { # dates in the tissue dataset are formatted differently than the other datasets
        field_types <- str_replace_all(string = field_types, pattern = 'T', replacement = 'c')
    }
    
    
    options(warn = 2) # this converts warnings into errors, so that the function below will stop if there is a problem reading in the data
    
    
    #### create folder and parquet file for each year from 2000 to present ####
        walk(2000:latest_year, ~ convert_data(., directory_name, file_name))

    #### pre-2000 data ####
    # read file
    df_ceden_pre2000 <- read_csv(glue('{data_files_path}\\{download_date}\\{file_name}_prior_to_2000_{download_date}.csv'), 
                                      col_types = field_types, 
                                      na = 'NaN') %>% 
        mutate(sample_year = year(SampleDate))
    if (file_name == 'TissueData') { # dates in the tissue dataset are formatted differently than the other datasets
        df_ceden_pre2000 <- df_ceden_pre2000 %>% 
            mutate_at(vars(contains(c('EarliestDateSampled', 'PrepPreservationDate', 
                                      'DigestExtractDate', 'AnalysisDate', 'LatestDateSampled', 
                                      'HomogonizedDate'))), mdy) %>% # 'CompositeSampleDate', 
            mutate(SampleDate = ymd(SampleDate))
    }

    # get a list of years in the dataset
    list_years_pre2000 <- df_ceden_pre2000 %>% 
        distinct(sample_year) %>% 
        arrange(sample_year) %>% 
        pull(sample_year)
    
    # create folder and parquet file for each year
        walk(list_years_pre2000, ~ convert_data_pre2000(., directory_name, df_ceden_pre2000))
        rm(df_ceden_pre2000)
        
        
    options(warn = 0) # this converts warnings back into regular warnings (not errors)
        
    
    # add all of the files to a zip file, but without compression (this file can be loaded to the data portal)
    zip::zip(zipfile = glue('{directory_name}.zip'), 
             root = paste0(file_save_location, directory_name),
             recurse = TRUE,
             #mode = 'cherry-pick',
             # files = glue('{directory_name}/{list.files(directory_name, recursive = TRUE)}'),
             files = list.files(recursive = TRUE),
             compression_level = 0)
    
    # move the zip file back to the working directory
    if (file.copy(from = glue('{file_save_location}{directory_name}/{directory_name}.zip'), to = file_save_location)) {
        unlink(glue('{file_save_location}{directory_name}/{directory_name}.zip'))
    }
    
    # delete the un-zipped folder
    unlink(paste0(file_save_location, directory_name), recursive = TRUE)
}
    

    
# #### TEST ############################################################################
# # open connection as arrow
#     directory_name_chem <- names(list_datasets[1])
#     directory_name_chem <- glue('{directory_name_chem}_{download_date}')
#     ds_chemistry <- open_dataset(directory_name_chem, partitioning = "year")
# 
# # pull some data
#     tic()
#     df_from_arrow_all <- ds_chemistry %>% 
#         select(year, Analyte, Unit, Result, MDL, RL) %>%
#         filter(Analyte %in% c("E. coli")) %>% 
#         collect() 
#     toc()
#     
#     df_from_arrow_all %>% count(Analyte)
#     View(df_from_arrow_all %>% count(year))
# 
# # pull some data then summarize
#     tic()
#     df_from_arrow_all_summarize <- ds_chemistry %>% 
#         select(year, Analyte, Unit, Result, MDL, RL) %>%
#         filter(Analyte %in% c("E. coli")) %>% 
#         # collect() %>% 
#         group_by(Analyte, Unit, year) %>%
#         collect() %>% 
#         summarize(
#             avg_result = mean(Result, na.rm = TRUE),
#             max_result = max(Result, na.rm = TRUE),
#             n = n()
#         ) %>%
#         {.}
#     toc()
#     df_from_arrow_all_summarize
# 
# # get number of records by year
#     tic()
#     df_from_arrow_all_counts <- ds_chemistry %>% 
#         select(year, Analyte, Unit, Result, MDL, RL) %>%
#         # filter(Analyte %in% c("E. coli")) %>% 
#         collect() %>%
#         count(year) %>% 
#         # collect() %>% 
#         # summarize(
#         #     avg_result = mean(Result, na.rm = TRUE),
#         #     max_result = max(Result, na.rm = TRUE),
#         #     n = n()
#         # ) %>%
#         {.}
#     toc()
#     View(df_from_arrow_all_counts)
#     
#     
# # single year
#     tic()
#     df_from_arrow_one_year <- ds_chemistry %>% 
#         # select(year, Analyte, Unit, Result, MDL, RL) %>%
#         filter(Analyte %in% c("E. coli"), 
#                year == 2018) %>%
#         collect() %>%
#         # count(year) %>% 
#         # collect() %>% 
#         # summarize(
#         #     avg_result = mean(Result, na.rm = TRUE),
#         #     max_result = max(Result, na.rm = TRUE),
#         #     n = n()
#         # ) %>%
#         {.}
#     toc()
#     View(df_from_arrow_all_counts)
# # XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
# 
# 
