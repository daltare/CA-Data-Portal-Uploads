# download, format, and load eSMR data to the data.ca.gov portal


# load libraries ----------------------------------------------------------
library(tidyverse)
library(tictoc)
library(janitor)
library(lubridate)
library(ckanr)
library(glue)
library(blastula)
library(sendmailR)
library(reticulate)


# 1 - user input --------------------------------------------------------------------------------------------------------------------------------------------
## set download directory ----
##(i.e., where to save any downloaded files)
download_dir <- 'C:\\David\\_CA_data_portal\\Surface-Water-Datasets\\esmr\\'

# define file name for output csv files
file_name <- 'esmr_analytical_export_'

## data source ----
esmr_url <- 'https://intapps.waterboards.ca.gov/downloadFile/faces/flatFilesCiwqs.xhtml?fileName=esmr_analytical_export.txt'

# define which years to extract from the dataset and write to the data.ca.gov portal
## per discussion with Jarma, typically just update the current and previous years - for other years, update ~ once per year
# years_write <- 2006:year(Sys.Date())
years_write <- (year(Sys.Date())-3):year(Sys.Date())

## delete old files
delete_old_versions <- TRUE # whether or not to delete previous versions of each dataset - FALSE means to keep the old versions
# NOTE: currently set to keep the versions from the current day if TRUE

## enter the email address to send warning emails from
### NOTE - if sending from a personal email address, you'll have to update the credentials -- see below
email_from <- 'david.altare@waterboards.ca.gov' # "gisscripts-noreply@waterboards.ca.gov"

## enter the email address (or addresses) to send warning emails to
email_to <- 'david.altare@waterboards.ca.gov' # c('david.altare@waterboards.ca.gov', 'waterdata@waterboards.ca.gov')

## get data portal API key ----
#### key is saved in the local environment (it's available on data.ca.gov by going to your user profile)
portal_key <- Sys.getenv('data_portal_key')


# 2 - setup automated email ---------------------------------------------------
## create credentials file (only need to do this once) ----
# create_smtp_creds_file(file = 'outlook_creds', 
#                        user = 'david.altare@waterboards.ca.gov',
#                        provider = 'outlook'
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

Here's the error message from R: *{error_msg_r}*

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
            credentials = creds_file("outlook_creds")
            # credentials = creds_key("outlook_key")
        )
    
    ### send email via sendmailR (for use on GIS scripting server) ----
    # from <- email_from
    # to <- email_to
    # sendmail(from,to,subject,body,control=list(smtpServer= "gwgate.waterboards.ca.gov"))
    
    print('sent automated email')
}



# delete old versions of files --------------------------------------------
tryCatch(
    if (delete_old_versions == TRUE) {
        files_list <- grep(pattern = paste0('^', file_name), 
                           x = list.files(download_dir), 
                           value = TRUE) # get a list of all of the files of this type (including the new one) (NOTE: ^ means: starts with..)
        files_to_keep <- c(paste0(file_name, 'year-', years_write, '_', Sys.Date(), '.csv'))
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




# download source data ----------------------------------------------------
### download to temp file, to avoid saving entire esmr dataset
tryCatch(
    {
        opt_timeout <- getOption('timeout')
        options(timeout = 3600)
        temp_file <- tempfile()
        tic()
        download.file(url = esmr_url, 
                      # destfile = paste0(download_dir, 
                      #                   'esmr_analytical_export_', 
                      #                   Sys.Date(), 
                      #                   '.txt'),
                      destfile = temp_file,
                      method = 'curl')
        options(timeout = opt_timeout)
        t <- toc()
        (time_download <- (t$toc - t$tic) / 60) # minutes 
    },
    error = function(e) {
        error_message <- 'downloading flat file data'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



# read data ---------------------------------------------------------------
tryCatch(
    {
        tic()
        df_esmr <- read_tsv(file = temp_file,
                            col_types = cols(.default = col_character()),
                            quote = '') %>%
            clean_names() %>%
            select(-matches('^x[123456789]')) %>% 
            # type_convert() %>% 
            {.}
        t2 <- toc()
        
        names_original <- names(df_esmr)
        (time_read <- (t2$toc - t2$tic) / 60) # minutes
        # glimpse(df_esmr)
        unlink(temp_file)
    },
    error = function(e) {
        error_message <- 'reading flat file data into R'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)


# investigate data --------------------------------------------------------

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
#           file = paste0(download_dir, 'esmr_sampling-date_summary_', Sys.Date(), '.csv'))

## look at invalid dates (missing, future, far past) ----
# df_invalid_missing <- df_esmr %>% 
#     filter(is.na(sampling_date)) %>% 
#     select(analysis_date, report_name, smr_document_id)
# View(df_invalid_missing)
# write_csv(df_invalid_missing,
#           file = paste0(download_dir, 'esmr_sampling-date_missing_', Sys.Date(), '.csv'))

# df_invalid_future <- df_esmr %>% 
#     filter(year(mdy(sampling_date)) > year(Sys.Date())) %>% 
#     select(sampling_date, analysis_date, report_name, smr_document_id)
# View(df_invalid_future)
# write_csv(df_invalid_future,
#           file = paste0(download_dir, 'esmr_sampling-date_invalid_future_', Sys.Date(), '.csv'))

# df_invalid_past <- df_esmr %>% 
#     filter(year(mdy(sampling_date)) < 2006) %>% 
#     select(sampling_date, analysis_date, report_name, smr_document_id)
# View(df_invalid_past)
# write_csv(df_invalid_past,
#           file = paste0(download_dir, 'esmr_sampling-date_invalid_past_', Sys.Date(), '.csv'))

# df_year <- df_esmr %>% 
#     filter(year(mdy(sampling_date)) == 2006) %>% 
#     select(sampling_date, analysis_date, report_name, smr_document_id)
# View(df_year)

## check specific dates ----
# df_esmr %>% filter(sampling_year < 1899) %>% pull(sampling_date)
# df_esmr %>% filter(sampling_year == 1931) %>% pull(sampling_date)



# format data -------------------------------------------------------------
## format date fields ----
gc()
tryCatch(
    {
        fields_dates <- c('sampling_date', 'analysis_date')
        # convert dates and times into a timestamp field that can be read by the portal
        for (counter in seq(length(fields_dates))) {
            # convert the date field to ISO format
            dates_iso <- mdy(df_esmr[[fields_dates[counter]]])
            # check NAs: sum(is.na(dates_iso))
            
            # Convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
            dates_iso <- as.character(dates_iso)
            # check: sum(is.na(dates_iso))
            dates_iso[is.na(dates_iso)] <- ''
            # check NAs: sum(is.na(dates_iso))
            
            # Insert the revised date field back into the dataset
            df_esmr[,fields_dates[counter]] <- dates_iso
        }
        # View(df_esmr %>% count(year(ymd(sampling_date))))
        rm(dates_iso)
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
gc()
tryCatch(
    {
        fields_numeric <- c('result', 'mdl', 'ml', 'rl', 'lattitude', 'longitude')
        ### convert to numeric
        for (counter in seq(length(fields_numeric))) {
            df_esmr[,fields_numeric[counter]] <- as.numeric(df_esmr[[fields_numeric[counter]]])
        }
    },
    error = function(e) {
        error_message <- 'formatting data (converting numeric fields)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)


## rename fields ----
gc()
tryCatch(
    {
        ### fix the latitude field (was named lattitude)
        df_esmr <- df_esmr %>% 
            rename(latitude = lattitude)
    },
    error = function(e) {
        error_message <- 'formatting data (rename fields)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)


## format text fields ----
gc()
tryCatch(
    {
        ### Convert missing values in text fields to 'NA' (to avoid converting to NaN)
        # from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
        # df_esmr <- df_esmr %>% 
        #     mutate_if(is.character, ~replace(., is.na(.), 'NA'))
        # mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))
        for (i in 1:length(df_esmr)) {
            if (class(df_esmr[[i]]) == 'character') {
                df_esmr[[i]][is.na(df_esmr[[i]])] <- 'NA'
            }
        }
    },
    error = function(e) {
        error_message <- 'formatting data (text fields)'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)


# filter by year / write output -------------------------------------------
gc()
tryCatch(
    {
        df_esmr <- df_esmr %>% 
            mutate(sampling_year = year(ymd(sampling_date)))
        # View(df_esmr %>% count(sampling_year)) # to see how many records there are per year
        for (i_year in years_write) { # 2006 is the first (reasonable) year with a substantial (>1000) number of records
            gc()
            write_csv(x = df_esmr %>% 
                          filter(sampling_year == i_year) %>% 
                          select(-sampling_year) %>% 
                          # mutate(analysis_date = analysis_date_rev,
                          #        sampling_date = sampling_date_rev) %>% 
                          # select(-analysis_date_rev, -analysis_year, -sampling_date_rev, -sampling_year) %>% 
                          {.}, 
                      file = paste0(download_dir, 
                                    'esmr_analytical_export_',
                                    'year-', i_year,
                                    '_', Sys.Date(),
                                    '.csv'), 
                      na = 'NaN')
        }
    },
    error = function(e) {
        error_message <- 'writing output data files'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



# test (read output files) --------------------------------------------------------------------
# df_test <- read_csv(paste0(download_dir, 'esmr_analytical_export_year-2016_',
#                            Sys.Date(), '.csv'),
#                     col_types = cols(.default = col_character())) %>%
#     type_convert()
# glimpse(df_test)


# write to portal ----------------------------------------------------------

## python (all years) ----
# tryCatch(py_run_file("C:\\Users\\daltare\\OneDrive - Water Boards\\projects\\CA_data_portal\\Surface-Water-Datasets\\portal-upload-ckan-chunked_eSMR\\main_eSMR.py"),
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
        last_year <- NA
        data_resource_id_list <-  list(
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
        # data_resource_id_list[[as.character(years_write)]]
        source_python('C:\\Users\\daltare\\OneDrive - Water Boards\\projects\\CA_data_portal\\Surface-Water-Datasets\\portal-upload-ckan-chunked_eSMR\\main_eSMR_function.py')
        files_date <- Sys.Date()
        for (i in as.character(years_write)) {
            print(glue('Updating Year: {i}'))
            ckanUploadFile(data_resource_id_list[[as.character(i)]],
                           paste0(download_dir, file_name, 'year-', as.character(i), '_', files_date, '.csv'),
                           portal_key)
            last_year <- i
            print(glue('Finished Updating Year: {i}'))
        }
    },
    error = function(e) {
        error_message <- glue('Uploading data to portal | last successful year uploaded: {last_year}')
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)
