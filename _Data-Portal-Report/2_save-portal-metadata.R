# (1) get data portal report and (2) save report files on sharepoint / teams


# setup -------------------------------------------------------------------
paths_output <- c('C:\\Users\\daltare\\Water Boards\\Data Integration & Analysis - CalEPA Open Data\\Data-Portal-Report',
                  'C:\\Users\\daltare\\Water Boards\\OIMA Data Team - Open Data\\Data-Portal-Report')


# load packages -----------------------------------------------------------
library(tidyverse)
library(writexl)
library(lubridate)



# get data ----------------------------------------------------------------
source('1_get-portal-metadata.R')



# write output files ------------------------------------------------------
for (output_path in paths_output) {
    
    # output_path <- paths_output[1] # for testing
    
    ## delete old versions ----
    # NOTE: Only needed if using date in filename
    # files_existing <- list.files(output_path)
    # files_remove <- files_existing[str_detect(string = files_existing, 
    #                                           pattern = 'DataPortalReport_[0-9]+-[0-9]+-[0-9]+.xlsx')]
    # files_remove <- c(files_remove, 
    #                   files_existing[str_detect(string = files_existing, 
    #                                           pattern = 'DataPortalReport-[Datasets|Resources]+_[0-9]+-[0-9]+-[0-9]+.csv')]
    # )
    # unlink(file.path(output_path, files_remove))
    
    
    ## combined datasets & resources (excel only) ----
    write_xlsx(x = list(datasets = df_datasets_format,
                        resources = df_resources_format), 
               path = paste0(output_path, '\\',
                             'DataPortalReport', 
                             # '_', Sys.Date() %>% with_tz(tzone = 'America/Los_Angeles'), 
                             '.xlsx'))
    
    ## datasets (csv) ----
    # write_excel_csv(x = df_datasets_format, 
    #                 file = paste0(output_path, '\\',
    #                               'DataPortalReport-Datasets_', 
    #                               Sys.Date(), '.csv'))
    
    
    ## resources (csv) ----
    # write_excel_csv(x = df_resources_format, 
    #                 file = paste0(output_path, '\\',
    #                               'DataPortalReport-Resources_', 
    #                               Sys.Date(), '.csv'))
}

print('Finished data portal report creation')
