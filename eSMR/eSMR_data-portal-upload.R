# download, format, and load eSMR data to the data.ca.gov portal


# load libraries ----------------------------------------------------------
{
    library(tidyverse)
    library(tictoc)
    library(janitor)
    library(lubridate)
    library(ckanr)
    library(glue)
    library(blastula)
    library(sendmailR)
    library(reticulate)
    library(checkpoint)
    library(readxl)
    library(zip)
    library(arrow)
    library(data.table)
    library(here)
    library(archive)
}

# 1 - user input --------------------------------------------------------------------------------------------------------------------------------------------
{
    ## set download directory ----
    ##(i.e., where to save any downloaded files)
    download_dir <- 'C:\\David\\_CA_data_portal\\eSMR\\'
    
    # define file name for output csv files
    file_name <- 'esmr-analytical-export'
    file_date <- Sys.Date()
    file_name_smr <- 'smr-export'
    
    ## data sources ----
    esmr_url <- 'https://intapps.waterboards.ca.gov/downloadFile/faces/flatFilesCiwqs.xhtml?fileName=esmr_analytical_export.txt'
    smr_url <- 'https://intapps.waterboards.ca.gov/downloadFile/faces/flatFilesCiwqs.xhtml?fileName=smr_export.txt'
    
    ## define date and numeric fields in the dataset (will determine how fields are formatted)
    fields_dates <- c('sampling_date', 'analysis_date')
    fields_numeric <- c('result', 'mdl', 'ml', 'rl', 'latitude', 'longitude', 
                        # 'facility_place_latitude', 'facility_place_longitude'
                        NULL
    )
    
    # define which years to extract from the dataset and write to the data.ca.gov portal
    ## years to download and write to local data files 
    years_download <- 2006:year(Sys.Date())
    ## years to write to portal -- per discussion with Jarma, typically just update the current and last few years - for other years, update ~ once per year
    years_write <- (year(Sys.Date())-4):year(Sys.Date()) 
    
    ## delete old files
    delete_old_versions <- TRUE # whether or not to delete previous versions of each dataset - FALSE means to keep the old versions
    # NOTE: currently set to keep the versions from the current day if TRUE
        ## enter the email address to send warning emails from
    ### NOTE - if sending from a personal email address, you'll have to update the credentials -- see below
    email_from <- 'daltare.swrcb@gmail.com' # 'david.altare@waterboards.ca.gov' # "gisscripts-noreply@waterboards.ca.gov"
    credentials_file <- 'gmail_creds' # this is the credentials file to be used (corresponds to the email_from address)
    # email_from <- "gisscripts-noreply@waterboards.ca.gov" # for GIS scripting server
    
    ## enter the email address (or addresses) to send warning emails to
    email_to <- 'david.altare@waterboards.ca.gov' 
    # email_to <- c('david.altare@waterboards.ca.gov', 'waterdata@waterboards.ca.gov') # for GIS scripting server
    
    ## get data portal API key ----
    #### key is saved in the local environment (it's available on data.ca.gov by going to your user profile)
    portal_key <- Sys.getenv('data_portal_key')
    
    ## data portal username and password ----
    portal_username <- Sys.getenv('portal_username')
    portal_password <- Sys.getenv('portal_password')
    
    ## define data portal resource IDs for all years in the dataset
    data_resource_id_list <-  list(
        '2022' = '8c6296f7-e226-42b7-9605-235cd33cdee2',
        '2021' = '28d3a164-7cec-4baf-9b11-7a9322544cd6',
        '2020' = '4fa56f3f-7dca-4dbd-bec4-fe53d5823905',
        '2019' = '2eaa2d55-9024-431e-b902-9676db949174',
        '2018' = 'bb3b3d85-44eb-4813-bbf9-ea3a0e623bb7',
        '2017' = '44d1f39c-f21b-4060-8225-c175eaea129d',
        '2016' = 'aacfe728-f063-452c-9dca-63482cc994ad',
        '2015' = '81c399d4-f661-4808-8e6b-8e543281f1c9',
        '2014' = 'c0f64b3f-d921-4eb9-aa95-af1827e5033e',
        '2013' = '8fefc243-9131-457f-b180-144654c1f481',
        '2012' = '67fe1c01-1c1c-416a-92e1-ee8437db615a',
        '2011' = 'c495ca93-6dbe-4b23-9d17-797127c28914',
        '2010' = '4eb833b3-f8e9-42e0-800e-2b1fe1e25b9c',
        '2009' = '3607ae5c-d479-4520-a2d6-3112cf92f32f',
        '2008' = 'c0e3c8be-1494-4833-b56d-f87707c9492c',
        '2007' = '7b99f591-23ac-4345-b645-9adfaf5873f9',
        '2006' = '763e2c90-7b7d-412e-bbb5-1f5327a5f84e'
    )
    
    ## define data portal resource IDs for zipped files
    zip_resource_id_list <- list(
        'ziped_csv' = list(dataset_name = 'water-quality-effluent-electronic-self-monitoring-report-esmr-data',
                           dataset_id = '5901c092-20e9-4614-b22b-37ee1e5c29a5',
                           data_file = glue('{download_dir}{file_name}_years-{min(years_download)}-{max(years_download)}_{file_date}.zip')),
        'parquet' = list(dataset_name = 'water-quality-effluent-electronic-self-monitoring-report-esmr-data',
                         dataset_id = 'cce982b3-719f-4852-8979-923c3a639a25',
                         data_file = glue('{download_dir}{file_name}_years-{min(years_download)}-{max(years_download)}_parquet_{file_date}.zip'))
    )
    
    ## name of the parquet directory / zipped file
    parquet_directory <- glue('{file_name}_years-{min(years_download)}-{max(years_download)}_parquet_{file_date}')
    
    ## define location of python script to upload chunked data (relative path)
    python_upload_script <- here('portal-upload-ckan-chunked_eSMR', 'main_eSMR_function.py')
    
    ## define location of the data dictionary spreadsheet (relative path)
    data_dictionary_path <- here('esmr-data-dictionary-tool', 'eSMR_Data_Dictionary_Template.xlsx')
}



# 2 - setup automated email ---------------------------------------------------
{
    ## create credentials file (only need to do this once) ----
    
    ### gmail credentials ----
    #### NOTE - for gmail, you have to create an 'App Password' and use that 
    #### instead of your normal password - see: 
    #### (https://support.google.com/accounts/answer/185833?hl=en) 
    #### Background here:
    #### https://github.com/rstudio/blastula/issues/228 
    # create_smtp_creds_file(file = credentials_file,
    #                        user = email_from,
    #                        provider = 'gmail'
    #                        )
    
    
    ## create email function ----
    fn_send_email <- function(error_msg, error_msg_r) {
        
        ### create components ----
        #### date/time ----
        date_time <- add_readable_time()
        
        #### body ----
        body <- glue(
            "Hi,
There was an error uploading the eSMR Analytical Data to the data.ca.gov portal on {Sys.Date()}.
                
------
                
The process failed at this step: *{error_msg}*

Here's the error message from R: *{glue_collapse(error_msg_r, sep = ' | ')}*

------
                
Here's the link to the dataset on the data portal: https://data.ca.gov/dataset/surface-water-electronic-self-monitoring-report-esmr-data
                
Here's the link to the flat file with the source data: https://intapps.waterboards.ca.gov/downloadFile/faces/flatFilesCiwqs.xhtml  (Export Type = SMR Analytical Data)"                
        )
        
        #### footer ----
        footer <- glue("Email sent on {date_time}.")
        
        #### subject ----
        subject <- "Data Portal Upload Error (eSMR Analytical Data)"
        
        ### create email ----
        email <- compose_email(
            body = md(body),
            footer = md(footer)
        )
        
        ### send email via blastula (using credentials file) ----
        email %>%
            smtp_send(
                to = email_to,
                from = email_from,
                subject = subject,
                credentials = creds_file(credentials_file)
                # credentials = creds_key("outlook_key")
            )
        
        ### send email via sendmailR (for use on GIS scripting server) ----
        # sendmail(email_from, email_to, subject, body, control=list(smtpServer= "")) # insert smtpServer name before use
        
        print('sent automated email')
    }
}


# 3 - delete old versions of files --------------------------------------------
tryCatch(
    if (delete_old_versions == TRUE) {
        files_list <- grep(pattern = paste0('^', file_name), 
                           x = list.files(download_dir), 
                           value = TRUE) # get a list of all of the files of this type (including the new one) (NOTE: ^ means: starts with..)
        files_to_keep <- c(paste0(file_name, '_year-', years_write, '_', file_date, '.csv'))
        files_list_old <- files_list[!(files_list %in% files_to_keep)] # exclude the new file from the list of files to be deleted
        if (length(files_list_old) > 0) {
            file.remove(paste0(download_dir, files_list_old))
        }
        
    },
    error = function(e) {
        error_message <- 'deleting old versions of dataset'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



# 4 - get raw eSMR data  ------------------------------------------------------
## eSMR download ----
### download to temp file, to avoid saving entire esmr dataset
tryCatch(
    {
        opt_timeout <- getOption('timeout')
        options(timeout = 3600)
        # temp_file <- tempfile()
        # tic()
        file_download <- glue('{download_dir}{file_name}_{file_date}_raw.txt')
        download.file(url = esmr_url, 
                      destfile = file_download,
                      # destfile = temp_file,
                      method = 'curl')
        options(timeout = opt_timeout)
        # t <- toc()
        # (time_download <- (t$toc - t$tic) / 60) # minutes 
        gc()
    },
    error = function(e) {
        error_message <- 'downloading flat file data'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

## read eSMR data ----
tryCatch(
    {
        df_esmr <- read_tsv(file = file_download,
                            col_types = cols(.default = col_character()),
                            quote = '',
                            lazy = FALSE) %>%
            clean_names() %>%
            # select(-matches('^x[123456789]')) %>% 
            # type_convert() %>% 
            {.}
        gc()
        
        # df_esmr <- fread(file_download, 
        #                    colClasses = 'character', 
        #                    quote = '', 
        #                    na.strings = c('', 'NA')) %>% 
        #     clean_names() %>% 
        #     as_tibble()
        
        # stop if the dataset is smaller than expected
        if (nrow(df_esmr) < 18 * 10^6) { # >18M rows as of 2022-02
            stop('full dataset likely not downloaded (dataset is smaller than expected)')
        }

    },
    error = function(e) {
        error_message <- 'reading flat file data into R'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

## save raw eSMR data to compressed file / delete uncompressed file ----
tryCatch(
    {
        gc()
        write_csv(x = df_esmr,
                  progress = TRUE,
                  file = glue('{download_dir}{file_name}_all-data_raw_{file_date}.csv.gz'))
        
        # ## data.table
        # fwrite(df_esmr, 
        #        file = glue('{download_dir}{file_name}_datatable-test_{file_date}.csv.gz'))
        
        ## parquet
        # write_parquet(df_esmr,
        #               glue('{download_dir}{file_name}_raw_{file_date}.parquet'))
        
        ## delete uncompressed file ----
        unlink(file_download)
        gc()
    },
    error = function(e) {
        error_message <- 'reading flat file data into R'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



# 4.1 - optional - read eSMR data (if raw data already saved) ------------------------------
if (!exists('df_esmr')) {
    df_esmr <- read_csv(glue('{download_dir}{file_name}_all-data_raw_{file_date}.csv.gz'),
                        col_types = cols(.default = col_character()))
}
# gc()




# XX - get supplemental data ---------------------------------------------------
## supplemental data download ----
### get data for additional fields from the smr_export file
# tryCatch(
#     {
#         gc()
#         opt_timeout <- getOption('timeout')
#         options(timeout = 3600)
#         file_download_smr <- glue('{download_dir}{file_name_smr}_{file_date}_raw.txt')
#         download.file(url = smr_url, 
#                       destfile = file_download_smr,
#                       method = 'curl')
#         options(timeout = opt_timeout)
#     },
#     error = function(e) {
#         error_message <- 'downloading supplemental flat file data'
#         error_message_r <- capture.output(cat(as.character(e)))
#         fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
#         print(glue('Error: {error_message}'))
#         stop(e)
#     }
# )

## read supplemental data ----
# tryCatch(
#     {
#         gc()
#         df_smr <- read_tsv(file = file_download_smr,
#                            col_types = cols(.default = col_character()),
#                            quote = '') %>%
#             clean_names() %>%
#             select(-matches('^x[123456789]')) %>% 
#             # type_convert() %>% 
#             {.}
#     },
#     error = function(e) {
#         error_message <- 'reading supplemental flat file data into R'
#         error_message_r <- capture.output(cat(as.character(e)))
#         fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
#         print(glue('Error: {error_message}'))
#         stop(e)
#     }
# )

## save raw SMR (supplemental) data to compressed file / delete uncompressed file ----
# tryCatch(
#     {
#         gc()
#         write_csv(x = df_smr,
#                   progress = TRUE,
#                   file = glue('{download_dir}{file_name_smr}_raw_{file_date}.csv.gz'))
#         
#         ## delete uncompressed file ----
#         unlink(file_download_smr)
#         gc()
#     },
#     error = function(e) {
#         error_message <- 'reading flat file data into R'
#         error_message_r <- capture.output(cat(as.character(e)))
#         fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
#         print(glue('Error: {error_message}'))
#         stop(e)
#     }
# )


# read supplemental data (if raw data already saved) ------------------------------
# df_smr <- read_csv(glue('{download_dir}{file_name_smr}_raw_{file_date}.csv.gz'),
#                     col_types = cols(.default = col_character()))
# if (!exists('df_esmr')) {
#     df_esmr <- read_parquet(glue('{download_dir}{file_name}_raw_{file_date}.parquet'), )
# }
# gc() 


# investigate data --------------------------------------------------------
## regions
# df_esmr %>% count(region) %>% collect() %>% arrange(region)
# gc()

## get year of all sampling dates in the dataset ----
# df_dates <- df_esmr %>%
#     select(sampling_date, analysis_date, report_name, smr_document_id) %>%
#     mutate(sampling_date_rev = mdy(sampling_date),
#            sampling_year = year(sampling_date_rev),
#            analysis_date_rev = mdy(analysis_date),
#            analysis_year = year(analysis_date_rev))
# df_dates_summary <- df_dates %>% count(sampling_year)
# View(df_dates_summary)
# write_csv(df_dates_summary,
#           file = paste0(download_dir, 'esmr_sampling-date_summary_', file_date, '.csv'))

## look at invalid dates (missing, future, far past) ----
# df_invalid_missing <- df_esmr %>% 
#     filter(is.na(sampling_date)) %>% 
#     select(analysis_date, report_name, smr_document_id)
# View(df_invalid_missing)
# write_csv(df_invalid_missing,
#           file = paste0(download_dir, 'esmr_sampling-date_missing_', file_date, '.csv'))

# df_invalid_future <- df_esmr %>% 
#     filter(year(mdy(sampling_date)) > year(file_date)) %>% 
#     select(sampling_date, analysis_date, report_name, smr_document_id)
# View(df_invalid_future)
# write_csv(df_invalid_future,
#           file = paste0(download_dir, 'esmr_sampling-date_invalid_future_', file_date, '.csv'))

# df_invalid_past <- df_esmr %>% 
#     filter(year(mdy(sampling_date)) < 2006) %>% 
#     select(sampling_date, analysis_date, report_name, smr_document_id)
# View(df_invalid_past)
# write_csv(df_invalid_past,
#           file = paste0(download_dir, 'esmr_sampling-date_invalid_past_', file_date, '.csv'))

# df_year <- df_esmr %>% 
#     filter(year(mdy(sampling_date)) == 2006) %>% 
#     select(sampling_date, analysis_date, report_name, smr_document_id)
# View(df_year)

## check specific dates ----
# df_esmr %>% filter(sampling_year < 1899) %>% pull(sampling_date)
# df_esmr %>% filter(sampling_year == 1931) %>% pull(sampling_date)



# XX - add supplemental data ---------------------------------------------------
### add additiona fields from the smr_export file (NPDES #, WDID #, county, facility lat/lon, etc.)
# tryCatch(
#     {
#         gc()
#         nrow_1 <- nrow(df_esmr) # save original # rows as check to make sure join doesn't add extra rows
#         
#         ## select desired supplemental fields
#         df_supplemental <- df_smr %>% 
#             select(smr_id, regulated_facility_id, npdes_num, wdid, 
#                    design_flow, place_address, place_city, place_county, 
#                    place_zip, place_latitude, place_longitude) %>% 
#             distinct()
#         ## remove the smr data
#         rm(df_smr)
#         gc()
#         ## rename fields
#         df_supplemental <- df_supplemental %>% 
#             rename(facility_place_address = place_address, 
#                    facility_place_city = place_city, 
#                    facility_place_county = place_county, 
#                    facility_place_zip = place_zip, 
#                    facility_place_latitude = place_latitude, 
#                    facility_place_longitude = place_longitude)
#         ## join supplemental data to esmr dataset
#         df_esmr <- df_esmr %>% 
#             left_join(df_supplemental,
#                       by = c('smr_document_id' = 'smr_id', 
#                              'facility_place_id' = 'regulated_facility_id')) 
#         gc()
#         ## check to make sure no new rows were added
#         nrow_2 <- nrow(df_esmr)
#         if (!(nrow_1 == nrow_2)) { # nrow_1 should equal nrow_2, if not generate an error
#             stop('new rows added to eSMR dataset')
#         }
#         rm(df_supplemental)
#         gc()
#     },
#     error = function(e) {
#         error_message <- 'adding supplemental data'
#         error_message_r <- capture.output(cat(as.character(e)))
#         fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
#         print(glue('Error: {error_message}'))
#         stop(e)
#     }
# )



# 5- format data -------------------------------------------------------------

## remove duplicates ----
tryCatch(
    {
        gc()
        df_esmr <- df_esmr %>% 
            distinct()
        gc()
    },
    error = function(e) {
        error_message <- 'removing duplicates'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

## rename fields ----
tryCatch(
    {
        gc()
        ### fix the latitude field (was named lattitude)
        df_esmr <- df_esmr %>% 
            rename(latitude = lattitude)
        gc()
    },
    error = function(e) {
        error_message <- 'formatting data (rename fields)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

## format date fields ----
tryCatch(
    {
        gc()
        # convert dates and times into a timestamp field that can be read by the portal
        for (counter in seq(length(fields_dates))) {
            # convert the date field to ISO format
            dates_iso <- mdy(df_esmr[[fields_dates[counter]]])
            # check NAs: sum(is.na(dates_iso))
            
            # # Convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
            # dates_iso <- as.character(dates_iso)
            # # check: sum(is.na(dates_iso))
            # dates_iso[is.na(dates_iso)] <- ''
            # # check NAs: sum(is.na(dates_iso))
            
            # Insert the revised date field back into the dataset
            df_esmr[,fields_dates[counter]] <- dates_iso
        }
        # View(df_esmr %>% count(year(ymd(sampling_date))))
        rm(dates_iso)
        gc()
    },
    error = function(e) {
        error_message <- 'formatting data (converting date fields)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

## format numeric fields ----
tryCatch(
    {
        gc()
        ### convert to numeric
        for (counter in seq(length(fields_numeric))) {
            df_esmr[,fields_numeric[counter]] <- as.numeric(df_esmr[[fields_numeric[counter]]])
        }
        gc()
    },
    error = function(e) {
        error_message <- 'formatting data (converting numeric fields)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

## character fields - remove characters for quotes, tabs, returns, pipes, etc ----
tryCatch(
    {
        gc()
        remove_characters <- c('\"|\t|\r|\n|\f|\v|\\|')
        # df_esmr <- df_esmr %>%
        #     map_df(~str_replace_all(., remove_characters, ' '))
        df_esmr <- df_esmr %>%
            mutate(across(where(is.character), 
                          ~ str_replace_all(string = .x, 
                                            pattern = remove_characters, 
                                            replacement = ' ')
            ))
        #     ### check - delete this later
        #     tf <- str_detect(replace_na(df_esmr$record_summary, 'NA'),
        #                     remove_characters)
        #     sum(tf)
        #     check_rows <- df_esmr$record_summary[tf]
        #     check_rows[1] # view first one
        #     check_rows_fixed <- str_replace_all(check_rows, remove_characters, ' ')
        #     check_rows_fixed[1] # view first one
        gc()
    },
    error = function(e) {
        error_message <- 'formatting data (removing special characters)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

## ensure all records are in UTF-8 format, convert if not ----
tryCatch(
    {
        # for (col_i in names(df_esmr)) {
        # # for (col_i in names(df_esmr)[1]) {
        #     df_esmr[[col_i]] <- iconv(df_esmr[[col_i]], to = 'UTF-8')
        #     gc()
        # }
        df_esmr <- df_esmr %>%
            # map_df(~iconv(., to = 'UTF-8')) %>% # this is probably slower
            mutate(across(where(is.character),
                          ~iconv(., to = 'UTF-8'))) %>%
            {.}
        gc()
    },
    error = function(e) {
        error_message <- 'formatting data (converting to UTF-8)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



# 6 - create parquet file -----------------------------------------------------
tryCatch(
    {
        gc()
        ## create variable for year sampled
        df_esmr <- df_esmr %>% 
            mutate(sampling_year = year(ymd(sampling_date)))
        ## save dataset first in case someting goes wrong
        # write_csv(x = df_esmr, 
        #           file = paste0(download_dir, 
        #                         file_name,
        #                         '_parquet-formatted',
        #                         '_', file_date,
        #                         '.csv.gz'))
        write_rds(x = df_esmr, 
                  compress = 'gz', compression = 1,
                  file = paste0(download_dir, 
                                file_name,
                                '_parquet-formatted',
                                '_', file_date,
                                '.rds')
        )
        
        # to start from here if needed
        if (!exists('df_esmr')) {
            df_esmr <- read_rds(paste0(download_dir,
                                       file_name,
                                       '_parquet-formatted',
                                       '_', file_date,
                                       '.rds'))
        }
        
        gc()
        # View(df_esmr %>% count(sampling_year)) # to see how many records there are per year
        
        ## partition by region first, sampling year second
        write_dataset(dataset = df_esmr %>%
                          filter(sampling_year %in% years_download),
                      path = glue('{download_dir}{parquet_directory}'),
                      format = 'parquet',
                      partitioning = c('region', 'sampling_year'))
        
        ## partition by region first, facility name second
        # reg <- unique(df_esmr$region)
        # for (i in seq_along(reg)) {
        #     write_dataset(dataset = df_esmr %>%
        #                       filter(sampling_year %in% years_download,
        #                              region == reg[i]) %>% 
        #                       mutate(facility_name = str_replace_all(facility_name, '/', '-')) %>% # replaces "Yountville / CA Vets Home WWTP"
        #                       select(-sampling_year),
        #                   path = glue('{download_dir}{parquet_directory}'),
        #                   format = 'parquet',
        #                   partitioning = c('region', 'facility_name'))
        # }
        gc()
        
        print(glue('Zipping parquet file'))
        
        # add all of the files to a zip file, but without compression (this file can be loaded to the data portal)
        zip::zip(zipfile = glue('{parquet_directory}.zip'), 
                 root = glue('{download_dir}{parquet_directory}'),
                 recurse = TRUE,
                 #mode = 'cherry-pick',
                 # files = glue('{directory_name}/{list.files(directory_name, recursive = TRUE)}'),
                 files = list.files(recursive = TRUE),
                 # compression_level = 0
                 )
        gc()
        Sys.sleep(2)
        
        # move the zip file back to the working directory
        if (file.copy(from = glue('{download_dir}{parquet_directory}\\{parquet_directory}.zip'), 
                      to = download_dir)) {
            unlink(glue('{download_dir}{parquet_directory}\\{parquet_directory}.zip'))
        }
        gc()
        Sys.sleep(2)
        
        # delete the un-zipped folder
        # unlink(glue('{download_dir}{parquet_directory}'), 
        #        recursive = TRUE)
        # gc()
        print(glue('---------- Finished creating parquet file ----------'))
        
    },
    error = function(e) {
        error_message <- 'writing parquet file'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

## 6.1 - (read parquet formatted data) ----
# if (!exists('df_esmr')) {
#     df_esmr <- read_rds(file = paste0(download_dir, 
#                                       file_name,
#                                       '_parquet-formatted',
#                                       '_', file_date,
#                                       '.rds'))
# }


# 7 - format data for portal compatibility -----------------------------------
## format date fields ----
tryCatch(
    {
        gc()
        # convert dates and times into a timestamp field that can be read by the portal
        ## convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
        for (col in fields_dates) {
            df_esmr <- df_esmr %>%
                mutate("{col}" := as.character(df_esmr[[col]]))
            df_esmr <- df_esmr %>% 
                mutate("{col}" := replace_na(df_esmr[[col]], ''))
        }
        # check
        # sum(is.na(df_esmr$sampling_date))
        # sum(df_esmr$sampling_date == '', na.rm = TRUE)
        # sum(is.na(df_esmr$analysis_date))
        # sum(df_esmr$analysis_date == '', na.rm = TRUE)
        
        gc()
    },
    error = function(e) {
        error_message <- 'formatting data for portal (converting date fields)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

## format numeric fields ----
tryCatch(
    {
        gc()
        # convert numeric fields into a numeric field that can be read by the portal
        ## convert data to text, and for NAs store as 'NaN' - this converts to 'null' in Postgres
        for (col in fields_numeric) {
            df_esmr <- df_esmr %>%
                mutate("{col}" := as.character(df_esmr[[col]]))
            df_esmr <- df_esmr %>% 
                mutate("{col}" := replace_na(df_esmr[[col]], 'NaN'))
        }
        # check
        # sum(is.na(df_esmr$result))
        # sum(df_esmr$result == 'NaN', na.rm = TRUE)
        # sum(is.na(df_esmr$mdl))
        # sum(df_esmr$mdl == 'NaN', na.rm = TRUE)
        
        gc()
    },
    error = function(e) {
        error_message <- 'formatting data for portal (converting numeric fields)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



## format text fields ----
# tryCatch(
#     {
#         gc()
#         ### Convert missing values in text fields to 'NA' (to avoid converting to NaN)
#         # from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
#         # df_esmr <- df_esmr %>% 
#         #     mutate_if(is.character, ~replace(., is.na(.), 'NA'))
#         # mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))
#         for (i in 1:length(df_esmr)) {
#             if (class(df_esmr[[i]]) == 'character') {
#                 df_esmr[[i]][is.na(df_esmr[[i]])] <- 'NA'
#             }
#         }
#         gc()
#     },
#     error = function(e) {
#         error_message <- 'formatting data (text fields)'
#         error_message_r <- capture.output(cat(as.character(e)))
#         fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
#         print(glue('Error: {error_message}'))
#         stop(e)
#     }
# )




# 8 - write individual year csv files -------------------------------------------
tryCatch(
    {
        gc()
        
        ## first save dataset to RDS, in case anything goes wrong
        write_rds(x = df_esmr, 
                  compress = 'gz', compression = 1,
                  file = paste0(download_dir, 
                                file_name,
                                '_portal-formatted',
                                '_', file_date,
                                '.rds')
        )
        
        # df_esmr <- df_esmr %>% 
        #     mutate(sampling_year = year(ymd(sampling_date)))
        # gc()
        # View(df_esmr %>% count(sampling_year)) # to see how many records there are per year
        for (i_year in years_download) { # 2006 is the first (reasonable) year with a substantial (>1000) number of records
            gc()
            write_csv(x = df_esmr %>% 
                          filter(sampling_year == i_year) %>% 
                          select(-sampling_year) %>% 
                          {.}, 
                      file = paste0(download_dir, 
                                    file_name,
                                    '_year-', i_year,
                                    '_', file_date,
                                    '.csv')) #, 
            # na = 'NaN')
        }
        
        gc()
        ## optionally, write the full dataset to a zip file
        # write_csv(x = df_esmr %>% 
        #               select(-sampling_year) %>% 
        #               {.}, 
        #           file = paste0(download_dir, 
        #                         file_name,
        #                         '_all-data',
        #                         '_', file_date,
        #                         '.csv.gz')
        # ) #, 
        # na = 'NaN')
        gc()
    },
    error = function(e) {
        error_message <- 'writing output data files (individual year csv files)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

# test (read output files)
# df_test <- read_csv(paste0(download_dir, 'esmr_analytical_export_year-2016_',
#                            file_date, '.csv'),
#                     col_types = cols(.default = col_character()),
#                     na = c('NA', 'NaN', '')
#                     ) %>%
#     type_convert()
# glimpse(df_test)


# write zip file (all years) ---------------------------------
tryCatch(
    {
        gc()
        
        write_csv(x = df_esmr %>% 
                      filter(sampling_year %in% years_download) %>% 
                      select(-sampling_year),
                  file = archive_write(archive = paste0(download_dir, file_name,
                                                        '_years-', min(years_download), 
                                                        '-', year(file_date),
                                                        '_', file_date,
                                                        '.zip'), 
                                       file = paste0(file_name,
                                                     '_years-', min(years_download), 
                                                     '-', year(file_date),
                                                     '_', file_date,
                                                     '.csv'))
        )
        
        ### write csv ----
        # write_csv(x = df_esmr %>% 
        #               filter(sampling_year %in% years_download) %>% 
        #               select(-sampling_year) %>% 
        #               # mutate(analysis_date = analysis_date_rev,
        #               #        sampling_date = sampling_date_rev) %>% 
        #               # select(-analysis_date_rev, -analysis_year, -sampling_date_rev, -sampling_year) %>% 
        #               {.}, 
        #           file = paste0(download_dir, 
        #                         file_name,
        #                         '_years-', min(years_download), 
        #                         '-', year(file_date),
        #                         '_', file_date,
        #                         '.csv') 
        # )#, 
        # # na = 'NaN')
        # 
        # ### convert to zip file ----
        # zip::zip(zipfile = paste0(file_name,
        #                           '_years-', min(years_download), 
        #                           '-', year(file_date),
        #                           '_', file_date,
        #                           '.zip'), 
        #          root = paste0(download_dir),
        #          # recurse = TRUE,
        #          # mode = 'cherry-pick',
        #          files = paste0(file_name,
        #                         '_years-', min(years_download),
        #                         '-', year(file_date),
        #                         '_', file_date,
        #                         '.csv')
        # )
        gc()
        Sys.sleep(2)
        
        # # delete the un-zipped file
        # unlink(paste0(download_dir, file_name,
        #               '_years-', min(years_download),
        #               '-', year(file_date),
        #               '_', file_date,
        #               '.csv'))
        gc() 
    },
    error = function(e) {
        error_message <- 'writing output data files (all years zip file)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



# remove full esmr dataset when finished ----------------------------------
tryCatch(
    {
        rm(df_esmr)
        gc()
    }, 
    error = function() { 
        # no action if already removed 
    }
)



# X - write parquet files --------------------------------------------
# tryCatch(
#     {
# #         ## optionally, use old version of arrow package (and all other packages for compatibility)
# #         checkpoint('2021-07-28')
# #         Sys.sleep(2)
# #         
# #         dir.create(glue('{download_dir}{parquet_directory}'))
# #         
# #         ## create a list of the column types, to use when reading in the data ----
# #         df_types <- read_xlsx(data_dictionary_path)
# #         field_types <- df_types %>% 
# #             pull(type) %>% 
# #             str_replace(pattern = 'text', replacement = 'c') %>% 
# #             str_replace(pattern = 'numeric', replacement = 'n') %>% 
# #             str_replace(pattern = 'timestamp', replacement = 'T') %>% 
# #             glue_collapse() %>% 
# #             as.character() %>% 
# #             {.}
# #         Sys.sleep(5)
# #         
# #         options(warn = 2) # this converts warnings into errors, so that the function below will stop if there is a problem reading in the data
# #         
# #         ## create function to create a parquet file for data partitioned by year ----
# #         convert_data <- function(year) {
# #             print(glue('Creating parquet file for: Year {year} ({Sys.time()})'))
# #             
# #             source_file <- glue('{download_dir}{file_name}_year-{year}_{file_date}.csv')
# #             
# #             ### create directory for the given year ----
# #             dir.create(glue('{download_dir}{parquet_directory}\\{year}'))
# #             
# #             gc()
# #             
# #             ### read source data file ----
# #             df_esmr_par <- read_csv(source_file, 
# #                                     col_types = field_types,
# #                                     na = c('NA', 'NaN', ''))
# #             print(glue('finished reading year {year} data'))
# #             
# #             # create parquet file
# #             print(glue('writing year {year} file'))
# #             write_parquet(df_esmr_par, 
# #                           sink = glue('{download_dir}{parquet_directory}\\{year}\\data.parquet'))
# #             
# #             rm(df_esmr_par)
# #             gc()
# #             Sys.sleep(1)
# #         }
# #         
# #         print(glue('---------- Creating parquet file ----------'))
# #         
# #         #### create folder and parquet file for each year from 2000 to present ####
# #         walk(years_download, ~ convert_data(.))
# #         
# #         options(warn = 0) # this converts warnings back into regular warnings (not errors)
# #         
# #         uncheckpoint()
# #         Sys.sleep(5)
# #         
# #         gc()
# #         
#         print(glue('Zipping parquet file'))
#         
#         # add all of the files to a zip file, but without compression (this file can be loaded to the data portal)
#         zip::zip(zipfile = glue('{parquet_directory}.zip'), 
#                  root = glue('{download_dir}{parquet_directory}'),
#                  recurse = TRUE,
#                  #mode = 'cherry-pick',
#                  # files = glue('{directory_name}/{list.files(directory_name, recursive = TRUE)}'),
#                  files = list.files(recursive = TRUE),
#                  compression_level = 0)
#         gc()
#         Sys.sleep(2)
#         
#         # move the zip file back to the working directory
#         if (file.copy(from = glue('{download_dir}{parquet_directory}\\{parquet_directory}.zip'), 
#                       to = download_dir)) {
#             unlink(glue('{download_dir}{parquet_directory}\\{parquet_directory}.zip'))
#         }
#         gc()
#         Sys.sleep(2)
#         
#         # delete the un-zipped folder
#         unlink(glue('{download_dir}{parquet_directory}'), 
#                recursive = TRUE)
#         gc()
#         print(glue('---------- Finished creating parquet file ----------'))
#         
#     },
#     error = function(e) {
#         error_message <- 'writing output data files (parquet file)'
#         error_message_r <- capture.output(cat(as.character(e)))
#         fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
#         print(glue('Error: {error_message}'))
#         stop(e)
#     }
# )



# 9 - upload zip files to portal -----------------------------------------------
tryCatch(
    {
        source(here('eSMR_zip-file-uploads.R'))
    },
    error = function(e) {
        error_message <- 'uploading zip files to data portal (combined data file and parquet file)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
    
)



# 10 - upload csv files to portal ----------------------------------------------------------
## python (all years) ----
# tryCatch(py_run_file("C:\\Users\\daltare\\OneDrive - Water Boards\\projects\\CA_data_portal\\eSMR\\portal-upload-ckan-chunked_eSMR\\main_eSMR.py"),
#          error = function(e) {
#              error_message <- 'Uploading data to portal'
#              error_message_r <- capture.output(cat(as.character(e)))
#              fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
#              print(glue('Error: {error_message}'))
#              stop(e)
#          }
# )

## python - year-by-year ----
tryCatch(
    {
        gc()
        last_year <- NA
        
        ### get python function
        #### install dependent python packages
        shell('cd portal-upload-ckan-chunked_eSMR')
        shell('pip install -r requirements.txt')
        shell('cd ..')
        #### get function
        source_python(python_upload_script)
        
        for (i in as.character(rev(years_write))) {
            print(glue('Updating Year: {i}'))
            ckanUploadFile(data_resource_id_list[[as.character(i)]],
                           paste0(download_dir, file_name, '_year-', as.character(i), '_', file_date, '.csv'),
                           portal_key)
            last_year <- i
            print(glue('Finished Updating Year: {i}'))
            gc()
        }
    },
    error = function(e) {
        error_message <- glue('Uploading data to portal | last successful year uploaded: {last_year} (data loaded from newest to oldest)')
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)
