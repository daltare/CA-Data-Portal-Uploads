# Downloads data from CEDEN, and formats it for posting to the data.ca.gov
# open data portal



# load packages -----------------------------------------------------------
library(odbc) # for working with databases
library(DBI) # for working with databases
library(tidyverse)
library(lubridate)
library(glue)
library(tictoc)
library(here)
library(readxl)
library(zip)
# library(reticulate)
# library(blastula)
# library(sendmailR)

## timing
t_start <- Sys.time()

# user inputs -------------------------------------------------------------
## location where files will be saved ----
data_files_date <- Sys.Date() # '2021-09-24' # Sys.Date()
data_files_path <- glue('C:\\David\\_CA_data_portal\\CEDEN\\{data_files_date}\\')

## define datasets to download ----
tables_list = list(
    # 'toxicity' = list(file_name = 'ToxicityData',
    #                   table_name = 'ToxDmart_MV',
    #                   dictionary_name = 'CEDEN_Toxicity_Data_Dictionary.xlsx'),
    # 'benthic' = list(file_name = 'BenthicData',
    #                  table_name = 'BenthicDMart_MV',
    #                  dictionary_name = 'CEDEN_Benthic_Data_Dictionary.xlsx'),
    'chemistry' = list(file_name = 'WaterChemistryData',
                       table_name = 'WQDMart_MV',
                       dictionary_name = 'CEDEN_Chemistry_Data_Dictionary.xlsx')#,
    # 'tissue' = list(file_name = 'TissueData',
    #                 table_name = 'TissueDMart_MV',
    #                 dictionary_name = 'CEDEN_Tissue_Data_Dictionary.xlsx')#,
    # 'habitat' = list(file_name = 'HabitatData',
    #                  table_name = 'HabitatDMart_MV',
    #                  dictionary_name = 'CEDEN_Habitat_Data_Dictionary.xlsx')
)

## define years to download data for
### NOTE 1: this script gets the data in 1-year chunks (i.e. one database query 
###         and one output file per year), and also saves the data in another file 
###         with data combined across all years
### NOTE 2: use 'pre-2000' to get the data for all years prior to 2000 as one 
###         chunk (i.e. one query and one output file)
years_list <- 2011:2012 # c('pre-2000', as.character(2000:year(data_files_date)))


## get user ID, Password, and Server for CEDEN Data Mart ----
dm_user <- Sys.getenv('UID')
dm_password <- Sys.getenv('PWD')
dm_server <- Sys.getenv('SERVER1')

## data dictionaries location
data_dictionary_path <- here('data_dictionaries',
                             'data_dictionary_conversion')


# create directory to save files ------------------------------------------
if (!dir.exists(data_files_path)) {
    dir.create(data_files_path)
}


# initialize a data frame to save all sites data --------------------------
df_all_sites <- tibble(StationName = character(), 
                       StationCode = character(),
                       Latitude = numeric(), 
                       Longitude = numeric(),
                       Datum = character())


# setup CEDEN database connection -----------------------------------------
# References (SQL Server Connections)
# https://rviews.rstudio.com/2017/05/17/databases-using-r/
# https://support.rstudio.com/hc/en-us/articles/214510788-Setting-up-R-to-connect-to-SQL-Server-
# http://db.rstudio.com/odbc/
# https://rdrr.io/cran/RODBC/man/odbcClose.html
# https://cran.r-project.org/web/packages/odbc/odbc.pdf

con_CEDEN <- dbConnect(odbc(),
                       Driver = "SQL Server",
                       Server = dm_server,
                       Database = "DataMarts",
                       UID = dm_user, 
                       PWD = dm_password, 
                       Port = 1433)


# get / format data -------------------------------------------------------
for (data_type in names(tables_list)) {
    print(glue('\n\n---------- STARTING {toupper(data_type)} DATA ----------\n\n'))
    t_start_type <- Sys.time()
    # data_type <- 'habitat' # for testing
    # 'toxicity' 'benthic' 'chemistry' 'tissue' 'habitat'
    
    ## get file & table name for given data type ----
    data_file_name <- tables_list[[data_type]]$file_name
    data_table_name <- tables_list[[data_type]]$table_name
    data_dictionary_name <- tables_list[[data_type]]$dictionary_name
    
    ## create a temporary file to store combined data (across all years -- gets converted to zip file)
    temp_dir <- tempdir()
    # temp_file <- tempfile(pattern = glue('{data_file_name}_{data_files_date}.csv'), 
    #                       tmpdir = temp_dir,
    #                       fileext = '.csv')
    temp_file <- glue('{temp_dir}\\{data_file_name}_{data_files_date}.csv')
    
    ## index data ----
    query_text_index <- as.character(glue("SELECT * FROM {data_table_name}"))
    index <- dbColumnInfo(dbSendQuery(con_CEDEN, query_text_index))
    index$type <- as.integer(index$type)
    index <- index %>% arrange(desc(type))
    index_names <- glue_collapse(index$name, sep= ", ")
    
    ## fix column names than contain parentheses (for SQL statement)
    if (data_type == 'tissue') {
        index_names <- index_names %>%
            str_replace(pattern = 'WeightAvg\\(g\\)',
                        replacement = '[WeightAvg(g)]') %>%
            str_replace(pattern = 'TLMax\\(mm\\)',
                        replacement = '[TLMax(mm)]') %>%
            str_replace(pattern = 'TLAvgLength\\(mm\\)',
                        replacement = '[TLAvgLength(mm)]') %>%
            str_replace(pattern = 'TLMin\\(mm\\)',
                        replacement = '[TLMin(mm)]') %>%
            str_replace(pattern = 'SampleDateRange\\(Days\\)',
                        replacement = '[SampleDateRange(Days)]')
    }
    
    ## execute query - all records (for reference, not used) ----
    # query_text_all <- paste0("SELECT ", paste(index$name, sep="", collapse=", "), " FROM WebSvc_Tox")
    # query_text_all <- as.character(glue("SELECT {index_names} FROM {data_table_name}"))
    # dbGetQuery(con_CEDEN, query_text_all)
    
    
    ## loop through all years to get / format data ----
    for (get_year in years_list) {
        print(glue('querying year {get_year} {data_type} data'))
        t_start_year <- Sys.time()
        
        # get_year <- '2013' # for testing
        
        ### format query for pre-2000 years
        if (get_year == 'pre-2000') {
            if (data_type != 'tissue') {
                query_text_date <- glue("SELECT {index_names} FROM {data_table_name} WHERE SampleDate < '2000-01-01'") %>% 
                    as.character()
            } else {
                query_text_date <- glue("SELECT {index_names} FROM {data_table_name} WHERE CONVERT(date,SampleDate,111) < '2000-01-01'") %>%
                    as.character()
            }
        } 
        
        ### format query for years from 2000 through present 
        if (get_year != 'pre-2000') {
            if (data_type != 'tissue') {
                query_text_date <- glue("SELECT {index_names} FROM {data_table_name} WHERE SampleDate BETWEEN '{get_year}-01-01' AND '{get_year}-12-31'") %>% 
                    as.character()
            } else {
                query_text_date <- glue("SELECT {index_names} FROM {data_table_name} WHERE CONVERT(date,SampleDate,111) BETWEEN '{get_year}-01-01' AND '{get_year}-12-31'") %>%
                    as.character()
            }
        }
        
        ### execute query ---
        df_query_result <- dbGetQuery(con_CEDEN, query_text_date) %>% 
            as_tibble()
        gc()
        
        
        
        # format data ---------------------------------------------------------------
        print(glue('formatting year {get_year} {data_type} data'))
        
        ## rename target latitude and longitude columns ----
        if ('TargetLatitude' %in% names(df_query_result)){
            df_query_result <- df_query_result %>% 
                rename(Latitude = TargetLatitude)
        }
        
        if ('TargetLongitude' %in% names(df_query_result)){
            df_query_result <- df_query_result %>% 
                rename(Longitude = TargetLongitude)
        }
        
        if ('CompositeTargetLatitude' %in% names(df_query_result)){
            df_query_result <- df_query_result %>% 
                rename(CompositeLatitude = CompositeTargetLatitude)
        }
        
        if ('CompositeTargetLongitude' %in% names(df_query_result)){
            df_query_result <- df_query_result %>% 
                rename(CompositeLongitude = CompositeTargetLongitude)
        }
        
        ## make sure Longitude value is negative and less than 10000 (could be projected) ----
        df_query_result <- df_query_result %>% 
            mutate(Longitude = as.numeric(Longitude)) 
        
        if ('CompositeLongitude' %in% names(df_query_result)){
            df_query_result <- df_query_result %>% 
                mutate(CompositeLongitude = as.numeric(CompositeLongitude))
        }
        
        
        df_query_result <- df_query_result %>% 
            mutate(Longitude = case_when((Longitude > 0 & Longitude < 1000) ~ 
                                             -Longitude,
                                         TRUE ~ Longitude))
        if ('CompositeLongitude' %in% names(df_query_result)){
            df_query_result <- df_query_result %>% 
                mutate(CompositeLongitude = case_when((CompositeLongitude > 0 & CompositeLongitude < 1000) ~ 
                                                          -CompositeLongitude,
                                                      TRUE ~ CompositeLongitude))
        }
        gc()
        
        ## add new columns ----
        new_cols <- c('DataQuality', 'DataQualityIndicator', 'Datum')
        for (col_name in new_cols) {
            if (!(col_name %in% names(df_query_result))) {
                df_query_result[col_name] <- NA_character_
            }
        }
        
        
        ## ensure all records are in UTF-8 format, convert if not ----
        {
            # tic()
            df_query_result <- df_query_result %>% 
                # map_df(~iconv(., to = 'UTF-8')) %>% # this is probably slower
                mutate(across(everything(), 
                              ~iconv(., to = 'UTF-8'))) %>% 
                {.}
            # toc()
        }
        gc()
        
        
        ## remove characters for quotes, tabs, returns, pipes, etc ----
        remove_characters <- c('\"|\t|\r|\n|\f|\v|\\|')
        ### check for special characters - can delete this ----
        # z <- df_query_result %>% 
        #     # map_df(~str_replace_all(., remove_characters, ' ')) %>% 
        #     mutate(across(everything(),
        #                   ~str_detect(replace_na(., 'NA'), remove_characters))) %>% 
        #     {.}
        # z <- z %>% 
        #     mutate(Total = rowSums(.))
        # sum(z$Total) # should be zero
        ### remove the special characters ----
        {
            # tic()
            df_query_result <- df_query_result %>% 
                # map_df(~str_replace_all(., remove_characters, ' ')) %>% 
                mutate(across(everything(),
                              ~str_replace_all(., remove_characters, ''))) %>% 
                {.}
            # toc()
        }
        
        
        ## convert data types (based on data dictionaries) ----
        ### create a list of the column types ----
        df_types <- read_xlsx(glue('{data_dictionary_path}/{data_type}/{data_dictionary_name}'))
        fields_dates <- df_types %>% 
            filter(type == 'timestamp') %>% 
            pull(column)
        fields_numeric <- df_types %>% 
            filter(type == 'numeric') %>% 
            pull(column)
        
        
        ## convert date fields ----
        options(warn = 2) # this converts warnings into errors, so that the function below will stop if there is a problem reading in the data
        gc()
        # convert dates and times into a timestamp field that can be read by the portal
        for (counter in seq(length(fields_dates))) {
            # counter <- 1
            #### convert the date field to ISO format
            if (data_type %in% c('toxicity', 'benthic', 'habitat')) {
                dates_iso <- as.Date(df_query_result[[fields_dates[counter]]])
                # tryCatch({
                #     dates_iso <- ymd(df_query_result[[fields_dates[counter]]])
                # },
                # error = function() {
                #     dates_iso <- ymd_hms(df_query_result[[fields_dates[counter]]]) %>%
                #         as.Date()
                # })
            }
            if (data_type == 'chemistry') {
                dates_iso <- as.Date(df_query_result[[fields_dates[counter]]])
                # if (fields_dates[counter] %in% c('SampleDate', 'CalibrationDate')) {
                #     dates_iso <- as.Date(df_query_result[[fields_dates[counter]]])
                #     # tryCatch({
                #     #     dates_iso <- ymd(df_query_result[[fields_dates[counter]]])
                #     # },
                #     # error = function() {
                #     #     dates_iso <- ymd_hms(df_query_result[[fields_dates[counter]]]) %>%
                #     #         as.Date()
                #     # })
                # } else {
                #     dates_iso <- ymd_hms(df_query_result[[fields_dates[counter]]]) %>% 
                #         as.Date()
                # }
            }
            if (data_type == 'tissue') {
                if (fields_dates[counter] == 'SampleDate') {
                    dates_iso <- as.Date(df_query_result[[fields_dates[counter]]])
                    # dates_iso <- ymd(df_query_result[[fields_dates[counter]]])
                } else {
                    options(warn = 0)
                    tryCatch(
                        {
                            dates_iso <- mdy(df_query_result[[fields_dates[counter]]])
                        },
                        warning = function(e) {
                            warning(e)
                            print(glue('invalide dates: year: {get_year} | field: {fields_dates[counter]}'))
                            options(warn = 0)
                            dates_iso <- mdy(df_query_result[[fields_dates[counter]]], quiet = TRUE)
                            # for reference
                            invalid_dates <- df_query_result[[fields_dates[counter]]][is.na(mdy(df_query_result[[fields_dates[counter]]], quiet = TRUE))]
                            print(glue('invalid dates sample: "{glue_collapse(invalid_dates[1:1], sep = ", ")}"'))
                            options(warn = 2)
                        }
                    )
                    options(warn = 2)
                }
            }
            # check NAs: sum(is.na(dates_iso))
            
            #### Convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
            dates_iso <- as.character(dates_iso)
            # check: sum(is.na(dates_iso))
            dates_iso <- replace_na(dates_iso, '')
            # dates_iso[is.na(dates_iso)] <- ''
            # check NAs: sum(is.na(dates_iso))
            
            #### Insert the revised date field back into the dataset
            df_query_result[,fields_dates[counter]] <- dates_iso
        }
        options(warn = 0) # this converts warnings back into regular warnings (not errors)
        # View(df_query_result %>% count(year(ymd(sampling_date))))
        rm(dates_iso)
        
        
        ## format numeric fields ----
        gc()
        for (counter in seq(length(fields_numeric))) {
            df_query_result[,fields_numeric[counter]] <- as.numeric(df_query_result[[fields_numeric[counter]]])
        }
        
        
        ## save missing values in text fields as 'NA' ----
        gc()
        #### convert missing values in text fields to 'NA' to avoid converting those to NaN
        {
            # tic()
            df_query_result <- df_query_result %>% 
                mutate(across(where(is.character),
                              ~replace_na(., 'NA')))
            # toc()
        }
        
        
        ## re-order columns ----
        fields_all <- df_types %>% 
            pull(column)
        df_query_result <- df_query_result %>% 
            select(all_of(fields_all))
        
        
        ## DONE PRIMARY FORMATTING ----
        
        
        # get data quality indicators ---------------------------------------------
        
        
        # get all sites data ----------------------------------------------------------
        df_all_sites <- df_all_sites %>% 
            bind_rows(df_query_result %>% 
                          select(StationName, StationCode, Latitude, 
                                 Longitude, Datum) %>% 
                          distinct())
        df_all_sites <- df_all_sites %>%
            distinct()
        
        
        # write output csv files --------------------------------------------------
        gc()
        if (nrow(df_query_result) > 0) { # only write files where there is at least one record for the given year
            ## get the file name ----
            if (get_year == 'pre-2000') {
                file_name_year <- glue('{data_files_path}{data_file_name}_prior_to_2000_{data_files_date}_test.csv')
            } else {
                file_name_year <- glue('{data_files_path}{data_file_name}_year-{get_year}_{data_files_date}_test.csv')
            }
            
            ## write individual year file ----
            write_csv(x = df_query_result, 
                      file = file_name_year,
                      na = 'NaN')
            
            ## add to combined data file  ----
            ### stored in a temp location prior to converting to zip file
            # file_name_combined <- glue('{data_files_path}{data_file_name}_{data_files_date}__test.csv')
            if (!file.exists(temp_file)) {
                write_csv(x = df_query_result, 
                          file = temp_file,
                          na = 'NaN')
            } else {
                write_csv(x = df_query_result, 
                          file = temp_file,
                          na = 'NaN', 
                          append = TRUE)
            }
            
            ## add to combined gzip file (probably not needed) ----
            # file_name_combined_gz <- glue('{data_files_path}__test_{data_file_name}_{data_files_date}.csv.gz')
            # if (!file.exists(file_name_combined_gz)) {
            #     write_csv(x = df_query_result, 
            #               file = file_name_combined_gz,
            #               na = 'NaN')
            # } else {
            #     write_csv(x = df_query_result, 
            #               file = file_name_combined_gz,
            #               na = 'NaN', 
            #               append = TRUE)
            # }
            
            t_end_year <- Sys.time()
            t_total_year <- t_end_year - t_start_year
            print(glue('finished processing year {get_year} {data_type} data ({round(as.numeric(t_total_year), 2)} {units(t_total_year)})\n\n'))
            
        } # end of writing files for given year
        
        
    } # end of loop by year
    
    # convert combined data file to zip file ----------------------------------
    zip::zip(zipfile = glue('{data_file_name}_{data_files_date}.zip'),
             root = paste0(data_files_path),
             # recurse = TRUE,
             mode = 'cherry-pick',
             files = temp_file)
    gc()
    Sys.sleep(2)
    
    # for toxicity and benthic data, save the raw combined file
    ## these files are posted to the data.ca.gov portal
    if (data_type == 'toxicity' | data_type == 'benthic') {
        file.copy(from = temp_file,
                  to = glue('{data_files_path}{basename(temp_file)}'))
    }
    
    # clean up ----
    t_end_type <- Sys.time()
    t_total_type <- t_end_type - t_start_type
    unlink(temp_file)
    print(glue('\n\n---------- FINISHED {toupper(data_type)} DATA (Process Took {round(as.numeric(t_total_type), 2)} {units(t_total_type)}) ----------\n\n\n'))
    
    
} # end of loop for data type

# unlink(temp_dir, recursive = TRUE)
# tempdir() # keeps R from returning error messages



# write all sites data ----------------------------------------------------
## rename station code field to site code
df_all_sites <- df_all_sites %>% 
    rename(SiteCode = StationCode)
## convert NAs in text fields to "NA" (character), to avoid writing as 'NaN' in output file
df_all_sites <- df_all_sites %>% 
    mutate(across(where(is.character),
                  ~replace_na(., 'NA')))
## write file
write_csv(x = df_all_sites, 
          file = glue('{data_files_path}All_CEDEN_Sites_{data_files_date}.csv'),
          na = 'NaN')



# close connection --------------------------------------------------------
tryCatch(
    {
        dbDisconnect(con_CEDEN)
    },
    error = function(e) {
        # error_message <- 'closing CEDEN database connection'
        # error_message_r <- capture.output(cat(as.character(e)))
        # fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        # print(glue('Error: {error_message}'))
        # stop(e)
    }
)

t_end <- Sys.time()
t_total <- t_end - t_start
print(glue('Finished CEDEN Data Download -- Total Processing Time: {round(as.numeric(t_total), 2)} {units(t_total)}'))

