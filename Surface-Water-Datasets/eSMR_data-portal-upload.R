# download, format, and load esmr data to the data.ca.gov portal


# load libraries ----------------------------------------------------------
library(tidyverse)
library(tictoc)
library(janitor)
library(lubridate)
library(ckanr)
library(glue)
library(blastula)
library(reticulate)



# 1 - USER INPUT --------------------------------------------------------------------------------------------------------------------------------------------
## set download directory ----
##(i.e., where to save any downloaded files)
download_dir <- 'C:\\David\\_CA_data_portal\\Surface-Water-Datasets\\esmr\\'
file_name <- 'esmr_analytical_export_'
years_write <- 2006:year(Sys.Date())

## delete old files
delete_old_versions <- TRUE # whether or not to delete previous versions of each dataset - FALSE means to keep the old versions
# NOTE: currently set to keep the versions from the previous 7 days if TRUE
# -------------------------------------------------------------------------------------------------------------------------------------------------------#



# setup error handling ----
## automated email ----
### create credentials file (only need to do this once) ----
# create_smtp_creds_file(file = 'outlook_creds', 
#                        user = 'david.altare@waterboards.ca.gov',
#                        provider = 'outlook'
#                        )   

### create email function ----
fn_send_email <- function(error_msg) {
    
    ### create components ----
    #### date/time ----
    date_time <- add_readable_time()
    
    #### body ----
    body <- glue(
                "Hi,
There was an error uploading the eSMR Analytical Data to the data.ca.gov portal on {Sys.Date()}.
                
The process failed at this step: {error_msg}
                
Here's the link to the dataset on the data portal: 
                
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
            # to = c("david.altare@waterboards.ca.gov", "waterdata@waterboards.ca.gov"),
            to = "david.altare@waterboards.ca.gov",
            from = "david.altare@waterboards.ca.gov",
            subject = subject,
            credentials = creds_file("outlook_creds")
            # credentials = creds_key("outlook_key")
        )
    
    ## send email via sendmailR (for use on GIS scripting server) ----
    # from <- "gisscripts-noreply@waterboards.ca.gov"
    # to <- c("david.altare@waterboards.ca.gov", "waterdata@waterboards.ca.gov")
    # sendmail(from,to,subject,body,control=list(smtpServer= "gwgate.waterboards.ca.gov"))
    
    print('sent automated email')
}


# delete old versions of files ----
if (delete_old_versions == TRUE) {
        files_list <- grep(pattern = paste0('^', file_name), 
                           x = list.files(download_dir), 
                           value = TRUE) # get a list of all of the files of this type (including the new one) (NOTE: ^ means: starts with..)
        files_to_keep <- c(paste0(file_name, 'year-', years_write, '_', Sys.Date(), '.csv'))
        files_list_old <- files_list[!(files_list %in% files_to_keep)] # exclude the new file from the list of files to be deleted
        if (length(files_list_old) > 0) {
            file.remove(paste0(download_dir, files_list_old))
        }
        
    }



# download source data ----------------------------------------------------
## data source ----
esmr_url <- 'https://intapps.waterboards.ca.gov/downloadFile/faces/flatFilesCiwqs.xhtml?fileName=esmr_analytical_export.txt'

## download ----
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
        fn_send_email(error_msg = 'downloading flat file data')
        print('Error: downloading flat file data')
        stop()
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
        fn_send_email(error_msg = 'reading flat file data into R')
        print('Error: reading flat file data into R')
        stop()
    }
)

# format data -------------------------------------------------------------
# df_dates <- df_esmr %>% 
#     select(sampling_date, analysis_date) %>% 
#     mutate(sampling_date_rev = mdy(sampling_date),
#            sampling_year = year(sampling_date_rev),
#            analysis_date_rev = mdy(analysis_date),
#            analysis_year = year(analysis_date_rev))
# View(df_dates %>% count(sampling_year))

## check dates ----
# df_esmr <- df_esmr %>% 
#     mutate(sampling_date_rev = mdy(sampling_date),
#            sampling_year = year(sampling_date_rev),
#            analysis_date_rev = mdy(analysis_date),
#            analysis_year = year(analysis_date_rev))
## check years
# View(df_esmr %>% count(sampling_year))
# glimpse(df_esmr)

## check incorrect years
# df_esmr %>% filter(sampling_year < 1899) %>% pull(sampling_date)
# df_esmr %>% filter(sampling_year == 1931) %>% pull(sampling_date)


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
        fn_send_email(error_msg = 'formatting data (converting date fields)')
        print('Error: formatting data (converting date fields)')
        stop()
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
        fn_send_email(error_msg = 'formatting data (converting numeric fields)')
        print('Error: formatting data (converting numeric fields)')
        stop()
    }
)


## rename fields ----
tryCatch(
    {
        ### fix the latitude field (was named lattitude)
        df_esmr <- df_esmr %>% 
            rename(latitude = lattitude)
    },
    error = function(e) {
        fn_send_email(error_msg = 'formatting data (rename fields)')
        print('Error: formatting data (rename fields)')
        stop()
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
        fn_send_email(error_msg = 'formatting data (text fields)')
        print('Error: formatting data (text fields)')
        stop()
    }
)


# filter by year / write output -------------------------------------------
gc()
View(df_esmr %>% count(sampling_year)) # to see how many records there are per year
tryCatch(
    {
        df_esmr <- df_esmr %>% 
            mutate(sampling_year = year(ymd(sampling_date)))
        for (i_year in years_write) { # 2006 is the first (reasonable) year with a substantial (>1000) number of records
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
        fn_send_email(error_msg = 'writing output data files')
        print('Error: writing output data files')
        stop()
    }
)



# test --------------------------------------------------------------------
# df_test <- read_csv(paste0(download_dir, 'esmr_analytical_export_year-2016_',
#                            Sys.Date(), '.csv'),
#                     col_types = cols(.default = col_character())) %>%
#     type_convert()
# glimpse(df_test)


# write to portal ----------------------------------------------------------
### define year / dataset ----
data_year <- 2021
# resourceID <- '16ecdef6-25ef-4779-99a1-1b78f8f08b30' # 2018
out_file <- paste0(download_dir, 'esmr_analytical_export_year-', 
                   data_year, '_', Sys.Date(), '.csv')

## get portal API key ----
### key is saved in the local environment (it's available on data.ca.gov by going to your user profile)
portal_key <- Sys.getenv('data_portal_key')

## set the ckan defaults ----   
ckanr_setup(url = 'https://data.ca.gov/', key = portal_key)

## get resource info (just as a check) ----
# ckan_resource_info <- resource_show(id = resourceID, as = 'table')


## write to portal ----
# file_upload <- resource_update(id = resourceID, 
#                                path = out_file)
# tryCatch(file_upload <- resource_update(id = resourceID,
#                                         path = out_file),
#          error = function(e) {
#              fn_send_email(error_msg = 'sending data to portal (uploading data file)')
#              # tracker <<- 'Error: uploading data file to portal'
#              print('Error: uploading data file to portal')
#              stop()
#          }
# )

tryCatch(py_run_file("C:\\Users\\daltare\\OneDrive - Water Boards\\projects\\CA_data_portal\\Surface-Water-Datasets\\portal-upload-ckan-chunked_eSMR\\main_Tox_eSMR.py"),
         error = function(e) {
             fn_send_email(error_msg = 'sending data to portal (uploading data file)')
             # tracker <<- 'Error: uploading data file to portal'
             print('Error: uploading data file to portal')
             stop()
         }
)
