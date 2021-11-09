library(tidyverse)
library(lubridate)
library(glue)
library(readxl)
library(writexl)

# filepath_report <- 'C:\\David\\_CA_data_portal\\_Data-Portal-Report\\CKAN-Data-Portal-Report_2021-11-09.csv'
filepath_report <- 'C:\\David\\_CA_data_portal\\_Data-Portal-Report\\CKAN-Data-Portal-Report_2021-11-09.xlsx'
file_save_location <- 'C:\\David\\_CA_data_portal\\_Data-Portal-Report\\'

# df_report <- read_csv(filepath_report)
df_report <- read_xlsx(filepath_report)
glimpse(df_report)

## all csv resources, by dataset
csv_resources <- df_report %>% 
    filter(resource_type == 'CSV') %>% 
    count(dataset_title) %>% 
    arrange(dataset_title)
View(csv_resources)
sum(csv_resources$n) # total csv resources
nrow(csv_resources) # total datasets
write_csv(x = csv_resources_2021, 
          file = glue(file_save_location, 'wb-csv-resources-all.csv'))
write_xlsx(x = csv_resources_2021, 
          path = glue(file_save_location, 'wb-csv-resources-all.xlsx'))


csv_resources_2021 <- df_report %>% 
    filter(resource_type == 'CSV',
           resource_last_update > '2021-01-01') %>% 
    count(dataset_title) %>% 
    arrange(dataset_title)
View(csv_resources_2021)
sum(csv_resources_2021$n) # total csv resources updated in 2021
nrow(csv_resources_2021) # total datasets with resources updated in 2021
write_csv(x = csv_resources_2021, 
          file = glue(file_save_location, 'wb-csv-resources-updated-2021.csv'))
write_xlsx(x = csv_resources_2021, 
          path = glue(file_save_location, 'wb-csv-resources-updated-2021.xlsx'))

