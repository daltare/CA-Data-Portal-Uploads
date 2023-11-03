# NOTE: To schedule this script to run automatically, go to 'Addins' and 'Schedule R scripts on...', then select 
# the file that calls this script ("C:\\David\\Open_Data_Project\\__CA_DataPortal\\_Call_Scripts\\Call_SurfWater_Script.R")
# and set the time/date option (make sure the date format is %m/%d/%Y)



# load packages -----------------------------------------------------------
{
  library(odbc) # for working with databases
  library(DBI) # for working with databases
  library(tidyverse)
  library(lubridate)
  library(ckanr) # for working with CKAN data portal
  library(reticulate)
  library(glue)
  library(blastula)
  library(sendmailR)
  library(gmailr)
}



# user inputs -------------------------------------------------------------
{
  ## define data portal resource IDs for the summary and replicate records
  resourceID_summary <- '674474eb-e093-42de-aef3-da84fd2ff2d8' # https://data.ca.gov/dataset/surface-water-toxicity-results/resource/674474eb-e093-42de-aef3-da84fd2ff2d8
  resourceID_replicate <- '6fd7b8d7-f8dd-454f-98bb-07e8cc710db8' # https://data.ca.gov/dataset/surface-water-toxicity-results/resource/6fd7b8d7-f8dd-454f-98bb-07e8cc710db8
  
  ## get data portal API key ----
  #### key is saved in the local environment (it's available on data.ca.gov by going to your user profile)
  portal_key <- Sys.getenv('data_portal_key')
  
  ## define location where files will be saved
  file_save_location <- 'C:\\David\\_CA_data_portal\\Toxicity\\'
  
  ## delete old versions of the datasets
  delete_old_versions <- TRUE
  filename_summary <- 'Toxicity-Summary-Records_'
  filename_replicate <- 'Toxicity-Replicate-Records_'
  
  ## get user ID and Password for CEDEN Data Mart
  dm_user <- Sys.getenv('ceden_user_id')
  dm_password <- Sys.getenv('ceden_password')
  dm_server <- Sys.getenv('ceden_server')
  
  ## send email if process fails?
  send_failure_email <- TRUE # may be useful to set this to FALSE (ie turn off emails) if the email functions fail (this especially may be the case when on the VPN)
  
  ## enter the email address to send warning emails from
  ### NOTE - if sending from a personal email address, you'll have to update the credentials -- see below
  email_from <- 'daltare.swrcb@gmail.com' # 'david.altare@waterboards.ca.gov' 
  
  ### email subject line ----
  subject_line <- "Data Portal Upload Error - CEDEN Toxicity Summary / Replicate"
  
  ## create credentials file (only need to do this once) 
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
  credentials_file <- 'gmail_creds' # this is the credentials file to be used (corresponds to the email_from address)
  
  ## enter the email address (or addresses) to send warning emails to
  email_to <- 'david.altare@waterboards.ca.gov' 
  # email_to <- c('david.altare@waterboards.ca.gov', 'waterdata@waterboards.ca.gov') # for GIS scripting server
  
  ## define location of python script to upload chunked data (relative path)
  python_upload_script <- 'portal-upload-ckan-chunked_Tox\\main_Tox_function.py'
  chunked_upload_directory <- 'portal-upload-ckan-chunked_Tox'
}



# setup automated email -----------------------------------------------

## create email function ----
fn_send_email <- function(error_msg, error_msg_r) {
  
  ### create components ----
  #### date/time ----
  date_time <- add_readable_time()
  
  #### body ----
  body <- glue(
    "Hi,
        
There was an error uploading the CEDEN Toxicity Summary / Replicate data to the data.ca.gov portal on {Sys.Date()}.

------
                
The process failed at this step: *{error_msg}*

Here's the error message from R: *{glue_collapse(error_msg_r, sep = ' | ')}*

------
                
Here's the link to the summary dataset on the data portal: https://data.ca.gov/dataset/surface-water-toxicity-results/resource/674474eb-e093-42de-aef3-da84fd2ff2d8

Here's the link to the replicate dataset on the data portal: https://data.ca.gov/dataset/surface-water-toxicity-results/resource/6fd7b8d7-f8dd-454f-98bb-07e8cc710db8
                
The source data comes from the CEDEN datamart"                
  )
  
  #### footer ----
  footer <- glue("Email sent on {date_time}.")
  
  ### create email ----
  email <- compose_email(
    body = md(body),
    footer = md(footer)
  )
  
  
  ### send email via blastula (using credentials file) ----
  email %>%
    smtp_send(
      # to = c("david.altare@waterboards.ca.gov", "waterdata@waterboards.ca.gov"),
      to = email_to,
      from = email_from,
      subject = subject_line,
      credentials = creds_file(credentials_file)
      # credentials = creds_key("outlook_key")
    )
  
  ### send email via sendmailR (for use on GIS scripting server) ----
  # from <- email_from
  # to <- email_to
  # sendmail(from,to,subject,body,control=list(smtpServer= ""))
  
  print('sent automated email')
}


## gmailr function ----
### NOTE: blastula may not work when on the waterboard VPN, but gmailr might
### (it's hard to tell if that will always be the case though)
### setting up gmailr is somewhat complicated, instructions are here:
### https://github.com/r-lib/gmailr 
### in particular note the OAuth steps: https://gmailr.r-lib.org/dev/articles/oauth-client.html
fn_email_gmailr <- function(error_msg, error_msg_r) {
  
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
  
  email_message <-
    gm_mime() |>
    gm_to(email_to) |>
    gm_from(email_from) |>
    gm_subject(subject_line) |>
    gm_text_body(body)
  
  gm_send_message(email_message)
}


# delete old versions of dataset --------------------------------------
tryCatch(
  {
    if (delete_old_versions == TRUE) {
      files_list <- grep(pattern = paste0('^', filename_summary), x = list.files(file_save_location), value = TRUE) # get a list of all of the files of this type (including the new one) (NOTE: ^ means: starts with..)
      files_list <- c(files_list,
                      grep(pattern = paste0('^', filename_replicate), x = list.files(file_save_location), value = TRUE))
      # files_list_old <- files_list[files_list != paste0(filename, '_', Sys.Date(), '_Raw.txt')] # exclude the new file from the list of files to be deleted
      files_to_keep <- c(paste0(filename_summary, Sys.Date() - seq(0,7), '.csv'),
                         paste0(filename_replicate, Sys.Date() - seq(0,7), '.csv')) # keep the files from the previous 7 days
      files_to_keep <- files_to_keep[files_to_keep %in% files_list]
      files_list_old <- files_list[!(files_list %in% files_to_keep)] # exclude the new file from the list of files to be deleted
      if (length(files_list_old) > 0 & length(files_to_keep) > 0) {
        file.remove(paste0(file_save_location, files_list_old))
      }
    }
  },
  error = function(e) {
    error_message <- 'deleting old versions of dataset'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)



# setup CEDEN database connection -----------------------------------------
# References (SQL Server Connections)
# https://rviews.rstudio.com/2017/05/17/databases-using-r/
# https://support.rstudio.com/hc/en-us/articles/214510788-Setting-up-R-to-connect-to-SQL-Server-
# http://db.rstudio.com/odbc/
# https://rdrr.io/cran/RODBC/man/odbcClose.html
# https://cran.r-project.org/web/packages/odbc/odbc.pdf
tryCatch(
  {
    con_CEDEN <- dbConnect(odbc(),
                           Driver = "SQL Server",
                           Server = dm_server, 
                           Database = "DataMarts",
                           UID = dm_user, 
                           PWD = dm_password, 
                           Port = 1433)
  },
  error = function(e) {
    error_message <- 'connecting to CEDEN database'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)


# query CEDEN database ----------------------------------------------------
# NOTE: There are two different methods in this script to retrieve the data and sort into summary vs replicate records -- only need to do one, not both (they should give the same result)

## all records ----
## METHOD 1 - Read all data from the database, then sort by summary or replicate records within R
#     # read all data
#         WebSvc_Tox <- dbReadTable(con_CEDEN, 'WebSvc_Tox')
#         
#     # Close connection 
#         dbDisconnect(con_CEDEN)
#     
#     # Subset data to select summary or replicate records only
#     # Required fields for summary records -- RepCount, Mean, StdDev, StatMethod, AlphaLevel, Probability, CriticalValue, PctControl, EvalThreshold, SigEffectCode
#     # Optional fields for summary records -- bValue, CalcValueType, PercentEffect, MSD, ToxPointSummaryComments
#         summary_records_tf <- !is.na(WebSvc_Tox$RepCount) | 
#             !is.na(WebSvc_Tox$Mean) | 
#             !is.na(WebSvc_Tox$StdDev) | 
#             !is.na(WebSvc_Tox$StatMethod) | 
#             !is.na(WebSvc_Tox$AlphaLevel) | 
#             !is.na(WebSvc_Tox$Probability) |
#             !is.na(WebSvc_Tox$CriticalValue) |
#             !is.na(WebSvc_Tox$PctControl) |
#             !is.na(WebSvc_Tox$EvalThreshold) |
#             !is.na(WebSvc_Tox$SigEffectCode)
#         
#         summary_records <- WebSvc_Tox[summary_records_tf, ]
#         replicate_records <- WebSvc_Tox[!summary_records_tf, ]

## METHOD 2 - Query for either summary or replicate records, using SQL statements
# run queries and import the result to R
# All records
# Method 1
# query_CEDEN_all <- dbSendQuery(con_CEDEN, "SELECT * FROM WebSvc_Tox")
# all_records <- dbFetch(query_CEDEN_all)
# Method 2
#all_records <- dbReadTable(con_CEDEN, 'WebSvc_Tox')
#all_records_count <- nrow(all_records)
# rm(list = c('all_records'))  

## Method 3 (fix - 2020-03-10) # https://stackoverflow.com/questions/45001152/r-dbi-odbc-error-nanodbc-nanodbc-cpp3110-07009-microsoftodbc-driver-13-fo
tryCatch(
  {
    index <- dbColumnInfo(dbSendQuery(con_CEDEN, "SELECT * FROM WebSvc_Tox"))
    index$type <- as.integer(index$type)
    index <- index %>% arrange(desc(type))
    query_text_all <- paste0("SELECT ", paste(index$name, sep="", collapse=", "), " FROM WebSvc_Tox")
    query_CEDEN_all <- dbSendQuery(con_CEDEN, query_text_all)
    all_records <- dbFetch(query_CEDEN_all)
    all_records_count <- nrow(all_records)
  },
  error = function(e) {
    error_message <- 'querying CEDEN database (all records)'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)



## summary records ----
tryCatch(
  {
    # query_CEDEN_summary <- dbSendQuery(con_CEDEN, "SELECT * FROM WebSvc_Tox WHERE 
    #                                     Mean IS NOT NULL AND
    #                                     StdDev IS NOT NULL AND
    #                                     StatMethod IS NOT NULL AND
    #                                     AlphaLevel IS NOT NULL AND
    #                                     Probability IS NOT NULL AND
    #                                     CriticalValue IS NOT NULL AND
    #                                     PctControl IS NOT NULL AND
    #                                     EvalThreshold IS NOT NULL AND
    #                                     SigEffectCode IS NOT NULL")
    # fix 2020-03-10
    query_text_summary <- paste0("SELECT ", paste(index$name, sep="", collapse=", "), " FROM WebSvc_Tox WHERE
                        Mean IS NOT NULL AND
                        StdDev IS NOT NULL AND
                        StatMethod IS NOT NULL AND
                        AlphaLevel IS NOT NULL AND
                        Probability IS NOT NULL AND
                        CriticalValue IS NOT NULL AND
                        PctControl IS NOT NULL AND
                        EvalThreshold IS NOT NULL AND
                        SigEffectCode IS NOT NULL")
    query_CEDEN_summary <- dbSendQuery(con_CEDEN, query_text_summary)
    summary_records <- dbFetch(query_CEDEN_summary)#, n = 1000)
    summary_records <- summary_records %>% mutate(SampleDate = as.Date(SampleDate))
    summary_records_distinct <- summary_records %>% select(-c('ToxID', 'LabReplicate', 'Result', 'ResQualCode', 'ToxResultComments', 'OrganismPerRep', 'ToxResultQACode')) %>% distinct()
    summary_records_distinct_noQA <- summary_records_distinct %>% filter(StationCode != 'LABQA_SWAMP')
  },
  error = function(e) {
    error_message <- 'querying CEDEN database (summary records)'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)

## replicate records ----
# Method to find replicate records:
# start with all records
# drop the 9 fields used in the query to get summary records
# drop ToxID field (just a unique ID for each row in the database)
# drop ToxPoint_MatrixName - this field is not included in the Replicate data exported to data.ca.gov, but it there are replicate records which are identical except for this field (so retaining this field would cause duplicates when the fields not included in the replicate data are dropped)
# drop records where LabReplicate is NA
# select just the distinct records
# drop records where StationCode is"LABQA_SWAMP" to get non-QA records
# Get the Replicates
tryCatch(
  {
    replicate_records <- all_records %>% 
      select(-c('Mean', 'StdDev', 'StatMethod', 'AlphaLevel', 'Probability', 
                'CriticalValue', 'PctControl', 'EvalThreshold', 'SigEffectCode')) %>% 
      select(-c('ToxID')) %>% 
      select(-c('ToxPoint_MatrixName')) %>% 
      filter(!is.na(LabReplicate))
    replicate_records_distinct <- replicate_records %>% distinct()
    replicate_records_noQA <- replicate_records %>% filter(StationCode != 'LABQA_SWAMP')
    replicate_records_noQA_distinct <- replicate_records_noQA %>% distinct()
  },
  error = function(e) {
    error_message <- 'selecting replicate records'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)

# check to see if there are any non-distinct records after the query to get the replicates
# result of the operation should be zero if all records are distinct
# nrow(replicate_records) - nrow(replicate_records_distinct)
# nrow(replicate_records_noQA) - nrow(replicate_records_noQA_distinct)

# # As a check, look at LabReplicate, and Result - if these are NA (or some other related value) it may indicate a summary record
#     # Look at cases where there are summary records (defined by the 9 fields) but the LabReplicate is NA or -88
#         table(summary_records$LabReplicate, useNA = 'ifany') # there are 20168 "NA" and 178 "-88"
#     # Look at cases where there are summary records but no Result value
#         min(summary_records$Result, na.rm = TRUE)
#         sum(summary_records$Result == -88, na.rm = TRUE) # 65 records where result is -88
#         sum(is.na(summary_records$Result)) # 23364 records where result is NA
#     summary_records_LabRepNA <- summary_records %>% filter(is.na(LabReplicate) & StationCode != 'LABQA_SWAMP')
#         View(summary_records_LabRepNA)
#         sum(is.na(summary_records_LabRepNA$Result)) # 17374 -- All of these records are missing a result value too - can probably get rid of them
#     summary_records_LabRep88 <- summary_records %>% filter(LabReplicate == -88)
#         sum(is.na(summary_records_LabRep88$Result)) # 5
#         table(summary_records_LabRep88$Result, useNA = 'ifany') # most of these have a distinct result
#         View(summary_records_LabRep88)
#     summary_records_ResultNA <- summary_records %>% filter(is.na(Result) & StationCode != 'LABQA_SWAMP' & !is.na(LabReplicate) & LabReplicate != -88)
#         View(summary_records_ResultNA)
#         table(summary_records_ResultNA$LabReplicate, useNA = 'ifany') # probably want to retain these values where result is NA since there are associated LabReplicate numbers for some

# Old method for getting the replicates
# query_CEDEN_replicate <- dbSendQuery(con_CEDEN, "SELECT * FROM WebSvc_Tox WHERE
#                                       Mean IS NULL AND
#                                       StdDev IS NULL AND
#                                       StatMethod IS NULL AND
#                                       AlphaLevel IS NULL AND
#                                       Probability IS NULL AND
#                                       CriticalValue IS NULL AND
#                                       PctControl IS NULL AND
#                                       EvalThreshold IS NULL AND
#                                       SigEffectCode IS NULL")
# replicate_records_Old <- dbFetch(query_CEDEN_replicate)#, n = 1000)
# replicate_records_Old <- replicate_records_Old %>% mutate(SampleDate = as.Date(SampleDate))

## close connection ----
tryCatch(
  {
    dbDisconnect(con_CEDEN)
  },
  error = function(e) {
    error_message <- 'closing CEDEN database connection'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)

# check -- number of records
# nrow(replicate_records) + nrow(summary_records) - all_records_count # should be zero - means all records in the database are within one of the two datasets

# # check
#     View(summary_records %>% select(Mean, StdDev, StatMethod, AlphaLevel, Probability, CriticalValue, PctControl, EvalThreshold, SigEffectCode))
#     View(replicate_records %>% select(Mean, StdDev, StatMethod, AlphaLevel, Probability, CriticalValue, PctControl, EvalThreshold, SigEffectCode))



# adjust field names ---------------------------------------------------------------
## get a list of the names used in the tox data entry template, and the 
## corresponding names used in the CEDEN database (for more info, see the 
## workbook called: Mapping_Fields_ToxTemplateToWebServices.xls)    

tryCatch(
  {
    # summary records - names in the CEDEN database and names in the data entry template
    summary_records_db_names <- c('StationCode', 'SampleDate', 'Project', 'EventCode', 'ProtocolCode', 
                                  'SampleAgencyCode', 'SampleComments', 'LocationName', 'GeometryShape', 'CollectionTime', 
                                  'CollectionMethodName', 'SampleTypeCode', 'CollectionReplicate', 'CollectionDeviceDescr', 'CollectionDepth', 
                                  'UnitCollectionDepth', 'PositionWaterColumn', 'CollectionComments', 'ToxBatch', 'MatrixName', 
                                  'MethodName', 'ToxTestDurCode', 'OrganismName', 'TestExposureType', 'QAControlID', 
                                  'SampleID', 'LabSampleID', 'ToxTestComments', 'Treatment', 'TreatmentConcentration', 
                                  'UnitTreatment', 'Dilution', 'CoordinateSource', 'ToxPointMethod', 'Analyte', 
                                  'Fraction', 'Unit', 'TimePointName', 'RepCount', 'Mean', 
                                  'StdDev', 'StatMethod', 'AlphaLevel', 'bValue', 'CalcValueType', 
                                  'Probability', 'CriticalValue', 'PercentEffect', 'MSD', 'EvalThreshold', 
                                  'SigEffectCode', 'QACode', 'ComplianceCode', 'ToxPointSummaryComments', 'TIENarrative', 
                                  'Program', 'ParentProject', 'TargetLatitude', 'TargetLongitude', 'Datum', 
                                  'PctControl', 'ToxBatch', 'ToxBatchStartDate', 'LabAgency', 'LabSubmissionCode', 
                                  'BatchVerificationCode', 'RefToxBatch', 'OrganismAgeAtTestStart', 'SubmittingAgency', 'OrganismSupplier', 
                                  'ToxBatchComments')
    tf_duplicated <- duplicated(summary_records_db_names)
    summary_records_db_names <- summary_records_db_names[!tf_duplicated]
    summary_records_template_names <- c('StationCode', 'SampleDate', 'ProjectCode', 'EventCode', 'ProtocolCode', # 1-5
                                        'AgencyCode', 'SampleComments', 'LocationCode', 'GeometryShape', 'CollectionTime', # 6-10
                                        'CollectionMethodCode', 'SampleTypeCode', 'Replicate', 'CollectionDeviceName', 'CollectionDepth', # 11-15
                                        'UnitCollectionDepth', 'PositionWaterColumn', 'LabCollectionComments', 'ToxBatch', 'MatrixName', # 16-20
                                        'MethodName', 'TestDuration', 'OrganismName', 'TestExposureType', 'QAControlID', 
                                        'SampleID', 'LabSampleID', 'ToxTestComments', 'Treatment', 'Concentration', 
                                        'UnitTreatment', 'Dilution', 'WQSource', 'ToxPointMethod', 'AnalyteName', 
                                        'FractionName', 'UnitAnalyte', 'TimePoint', 'RepCount', 'Mean', 
                                        'StdDev', 'StatisticalMethod', 'AlphaValue', 'bValue', 'CalcValueType', 
                                        'CalculatedValue', 'CriticalValue', 'PercentEffect', 'MSD', 'EvalThreshold', 
                                        'SigEffect', 'TestQACode', 'ComplianceCode', 'ToxPointSummaryComments', 'TIENarrative', 
                                        'Program', 'ParentProject', 'Lat', 'Long', 'Datum', 
                                        'PercentControl', 'ToxBatch', 'StartDate', 'LabAgencyCode', 'LabSubmissionCode', 
                                        'BatchVerificationCode', 'RefToxBatch', 'OrganismAgeAtTestStart', 'SubmittingAgencyCode', 'OrganismSupplier', 
                                        'ToxBatchComments')
    summary_records_template_names <- summary_records_template_names[!tf_duplicated]
    
    # replicate records - names in the CEDEN database and names in the data entry template
    replicate_records_db_names <- c('StationCode', 'SampleDate', 'Project', 'EventCode', 'ProtocolCode', 
                                    'SampleAgencyCode', 'SampleComments', 'LocationName', 'GeometryShape', 'CollectionTime', 
                                    'CollectionMethodName', 'SampleTypeCode', 'CollectionReplicate', 'CollectionDeviceDescr', 
                                    'CollectionDepth', 'UnitCollectionDepth', 'PositionWaterColumn', 'CollectionComments', 
                                    'ToxBatch', 'MatrixName', 'MethodName', 'ToxTestDurCode', 'OrganismName', 
                                    'TestExposureType', 'QAControlID', 'SampleID', 'LabSampleID', 'ToxTestComments', 
                                    'Treatment', 'TreatmentConcentration', 'UnitTreatment', 'Dilution', 'CoordinateSource', 
                                    'ToxPointMethod', 'Analyte', 'Fraction', 'Unit', 'TimePointName', 
                                    'LabReplicate', 'OrganismPerRep', 'Result', 'ResQualCode', 'ToxResultQACode', 
                                    'ComplianceCode', 'ToxResultComments', 'Program', 'ParentProject', 'TargetLatitude', 
                                    'TargetLongitude', 'Datum', 'ToxBatch', 'ToxBatchStartDate', 'LabAgency', 
                                    'LabSubmissionCode', 'BatchVerificationCode', 'RefToxBatch', 'OrganismAgeAtTestStart', 
                                    'SubmittingAgency', 'OrganismSupplier', 'ToxBatchComments')
    tf_duplicated <- duplicated(replicate_records_db_names)
    replicate_records_db_names <- replicate_records_db_names[!tf_duplicated]
    replicate_records_template_names <- c('StationCode', 'SampleDate', 'ProjectCode', 'EventCode', 'ProtocolCode', 
                                          'AgencyCode', 'SampleComments', 'LocationCode', 'GeometryShape', 'CollectionTime', 
                                          'CollectionMethodCode', 'SampleTypeCode', 'Replicate', 'CollectionDeviceName', 
                                          'CollectionDepth', 'UnitCollectionDepth', 'PositionWaterColumn', 'LabCollectionComments', 
                                          'ToxBatch', 'MatrixName', 'MethodName', 'TestDuration', 'OrganismName', 
                                          'TestExposureType', 'QAControlID', 'SampleID', 'LabSampleID', 'ToxTestComments', 
                                          'Treatment', 'Concentration', 'UnitTreatment', 'Dilution', 'WQSource', 
                                          'ToxPointMethod', 'AnalyteName', 'FractionName', 'UnitAnalyte', 'TimePoint', 
                                          'LabReplicate', 'OrganismPerRep', 'Result', 'ResQualCode', 'ToxResultQACode', 
                                          'ComplianceCode', 'ToxResultComments', 'Program', 'ParentProject', 'Lat', 
                                          'Long', 'Datum', 'ToxBatch', 'StartDate', 'LabAgencyCode', 
                                          'LabSubmissionCode', 'BatchVerificationCode', 'RefToxBatch', 'OrganismAgeAtTestStart', 
                                          'SubmittingAgencyCode', 'OrganismSupplier', 'ToxBatchComments')
    replicate_records_template_names <- replicate_records_template_names[!tf_duplicated]
  },
  error = function(e) {
    error_message <- 'adjusting field names'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)



# format data ----------------------------------------------------------

## define which data frame to use as the output ----
tryCatch(
  {
    summary_records_output <- summary_records_distinct
    replicate_records_output <- replicate_records_distinct
  },
  error = function(e) {
    error_message <- 'formatting data (defining output data frames)'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)

## select just the relevant fields for the output ----
tryCatch(
  {
    ### summary ----
    summary_records_output <- summary_records_output %>% select(all_of(summary_records_db_names))
    names(summary_records_output) <- summary_records_template_names
    
    ### replicate ----
    replicate_records_output <- replicate_records_output %>% select(all_of(replicate_records_db_names))
    names(replicate_records_output) <- replicate_records_template_names
    
    ## make sure the output records are still distinct ----
    ### summary ----
    summary_records_output_check <- summary_records_output %>% distinct()
    nrow(summary_records_output) - nrow(summary_records_output_check) # should be zero
    
    ### replicate ----
    replicate_records_output_check <- replicate_records_output %>% distinct()
    nrow(replicate_records_output) - nrow(replicate_records_output_check) # should be zero
  },
  error = function(e) {
    error_message <- 'formatting data (selecting fields for output data frames)'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)

# The code below was used to check which fields contain distinct values which are not included in the final output, and would result in duplicates when the un-used fields are dropped
# nrow(summary_records_output) - nrow(summary_records_output_check)
# z_summary_dup <- duplicated(summary_records_output) | duplicated(summary_records_output, fromLast = TRUE)
# sum(z_summary_dup)
# z_summary_dup <- summary_records_output[z_summary_dup,]
# View(z_summary_dup)
# z_summary_dup_2 <- z_summary_dup %>% filter(StationCode == z_summary_dup$StationCode[1])
# View(z_summary_dup_2)
# zzz <-  summary_records_distinct %>% filter(StationCode == z_summary_dup_2$StationCode[1] & SampleDate == z_summary_dup_2$SampleDate[1] & Analyte == z_summary_dup_2$AnalyteName[1] & ToxBatch == z_summary_dup_2$ToxBatch[1]) %>% distinct()
# View(zzz)

# nrow(replicate_records_output) - nrow(replicate_records_output_check)
# z_replicate_dup <- duplicated(replicate_records_output) | duplicated(replicate_records_output, fromLast = TRUE)
# sum(z_replicate_dup)
# z_replicate_dup <- replicate.records_output[z_replicate_dup,]
# View(z_replicate_dup)
# z_replicate_dup_2 <- z_replicate_dup %>% filter(StationCode == z_replicate_dup$StationCode[1])
# View(z_replicate_dup_2)
# zzz <-  replicate.records_distinct %>% filter(StationCode == z_replicate_dup_2$StationCode[1] & SampleDate == z_replicate_dup_2$SampleDate[1] & Analyte == z_replicate_dup_2$AnalyteName[1] & ToxBatch == z_replicate_dup_2$ToxBatch[1] & TimePointName == z_replicate_dup_2$TimePoint[1]) %>% distinct()
# View(zzz)


## check dataset for portal compatibility and adjust as needed  ----  

### summary records ----
#dplyr::glimpse(summary_records_output)

#### ensure all records are in UTF-8 format, convert if not ----
tryCatch(
  {
    summary_records_output <- summary_records_output %>%
      # map_df(~iconv(., to = 'UTF-8')) %>% # this is probably slower
      mutate(across(everything(), 
                    ~iconv(., to = 'UTF-8'))) %>% 
      {.}
  },
  error = function(e) {
    error_message <- 'formatting data (summary records - converting to UTF-8)'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)


#### remove characters for quotes, tabs, returns, pipes, etc ----
tryCatch(
  {
    remove_characters <- c('\"|\t|\r|\n|\f|\v|\\|')
    summary_records_output <- summary_records_output %>%
      map_df(~str_replace_all(., remove_characters, ' '))
  },
  error = function(e) {
    error_message <- 'formatting data (summary records - removing special characters)'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)

#### fix collection time field ----
tryCatch(
  {
    summary_records_output <- summary_records_output %>% 
      mutate(CollectionTime = paste(sep = ':',
                                    str_pad(hour(x = summary_records_output$CollectionTime),width = 2, pad = 0),
                                    str_pad(minute(x = summary_records_output$CollectionTime),width = 2, pad = 0),
                                    str_pad(second(x = summary_records_output$CollectionTime),width = 2, pad = 0)))
  },
  error = function(e) {
    error_message <- 'formatting data (summary records - collection time field)'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)

#### format date fields ----
##### convert dates into a timestamp field that can be read by the portal
tryCatch(
  {
    fields_dates <- c('SampleDate', 'StartDate')
    for (counter in seq(length(fields_dates))) {
      # convert the date field to ISO format
      dates_iso <- ymd(as.Date(summary_records_output[[fields_dates[counter]]]))
      # check NAs: sum(is.na(dates_iso))
      # Convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
      dates_iso <- as.character(dates_iso)
      # Check: sum(is.na(dates_iso))
      dates_iso[is.na(dates_iso)] <- ''
      # check NAs: sum(is.na(dates_iso))
      # Insert the revised date field back into the dataset
      summary_records_output[,fields_dates[counter]] <- dates_iso
    }
  },
  error = function(e) {
    error_message <- 'formatting data (summary records - date fields)'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)

#### format numeric fields ----
##### ensure all records are compatible with numeric format 
tryCatch(
  {
    ##### define numeric fields
    fields_numeric <- c('Replicate', 'CollectionDepth', 'Concentration', 'Dilution', 'RepCount', 
                        'Mean', 'StdDev', 'AlphaValue', 'bValue', 'CalculatedValue',
                        'CriticalValue', 'PercentEffect', 'MSD', 'EvalThreshold', 'Lat',
                        'Long')
    ##### convert to numeric
    for (counter in seq(length(fields_numeric))) {
      summary_records_output[,fields_numeric[counter]] <- as.numeric(summary_records_output[[fields_numeric[counter]]])
    }
  },
  error = function(e) {
    error_message <- 'formatting data (summary records - numeric fields)'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)

#### format text fields ----
##### Convert missing values in text fields to 'NA' (to avoid converting to NaN) !!!!!!!!!!!
##### from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
tryCatch(
  {
    summary_records_output <- summary_records_output %>% 
      mutate_if(is.character, ~replace(., is.na(.), 'NA'))
    # mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))
  },
  error = function(e) {
    error_message <- 'formatting data (summary records - text fields)'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)

### replicate records ----
dplyr::glimpse(replicate_records_output)

#### ensure all records are in UTF-8 format, convert if not ----
tryCatch(
  {
    replicate_records_output <- replicate_records_output %>%
      # map_df(~iconv(., to = 'UTF-8')) %>% # this is probably slower
      mutate(across(everything(), 
                    ~iconv(., to = 'UTF-8'))) %>% 
      {.}
  },
  error = function(e) {
    error_message <- 'formatting data (replicate records - converting to UTF-8)'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)

#### remove characters for quotes, tabs, returns, pipes, etc ----
tryCatch(
  {
    remove_characters <- c('\"|\t|\r|\n|\f|\v|\\|')
    replicate_records_output <- replicate_records_output %>%
      map_df(~str_replace_all(., remove_characters, ' '))
  },
  error = function(e) {
    error_message <- 'formatting data (replicate records - removing special characters)'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)

#### fix collection time field ----
tryCatch(
  {
    replicate_records_output <- replicate_records_output %>% 
      mutate(CollectionTime = paste(sep = ':',
                                    str_pad(hour(x = replicate_records_output$CollectionTime),width = 2, pad = 0),
                                    str_pad(minute(x = replicate_records_output$CollectionTime),width = 2, pad = 0),
                                    str_pad(second(x = replicate_records_output$CollectionTime),width = 2, pad = 0)))
  },
  error = function(e) {
    error_message <- 'formatting data (replicate records - collection time field)'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)

#### format date fields ----
##### convert dates into a timestamp field that can be read by the portal
tryCatch(
  {
    fields_dates <- c('SampleDate', 'StartDate')
    for (counter in seq(length(fields_dates))) {
      # convert the date field to ISO format
      dates_iso <- ymd(as.Date(replicate_records_output[[fields_dates[counter]]]))
      # check NAs: sum(is.na(dates_iso))
      # Convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
      dates_iso <- as.character(dates_iso)
      # Check: sum(is.na(dates_iso))
      dates_iso[is.na(dates_iso)] <- ''
      # check NAs: sum(is.na(dates_iso))
      # Insert the revised date field back into the dataset
      replicate_records_output[,fields_dates[counter]] <- dates_iso
    }
  },
  error = function(e) {
    error_message <- 'formatting data (replicate records - date fields)'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)

#### format numeric fields -----
##### ensure all records are compatible with numeric format 
tryCatch(
  {
    fields_numeric <- c('Replicate', 'CollectionDepth', 'Concentration', 'Dilution', 'LabReplicate', 'Result', 
                        'Lat', 'Long')
    # convert to numeric
    for (counter in seq(length(fields_numeric))) {
      replicate_records_output[,fields_numeric[counter]] <- as.numeric(replicate_records_output[[fields_numeric[counter]]])
    }
  },
  error = function(e) {
    error_message <- 'formatting data (replicate records - numeric fields)'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)

#### format text fields ----
tryCatch(
  {
    ##### Convert missing values in text fields to 'NA' (to avoid converting to NaN) !!!!!!!!!!!
    ##### from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
    replicate_records_output <- replicate_records_output %>% 
      mutate_if(is.character, ~replace(., is.na(.), 'NA'))
    # mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))
  },
  error = function(e) {
    error_message <- 'formatting data (replicate records - text fields)'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)


# write output csv files --------------------------------------------------
## Note: may have to do multiple steps to fix encoding

tryCatch(
  {
    ## define output filenames ----
    out_file_summary <- paste0(file_save_location, 'Toxicity-Summary-Records_', Sys.Date(), '.csv')
    out_file_replicate <- paste0(file_save_location, 'Toxicity-Replicate-Records_', Sys.Date(), '.csv')
    
    ## write to file using base write.csv, and specify encoding ----
    write.csv(x = summary_records_output, file = out_file_summary, row.names = FALSE, fileEncoding = 'UTF-8', na = 'NaN')
    write.csv(x = replicate_records_output, file = out_file_replicate, row.names = FALSE, fileEncoding = 'UTF-8', na = 'NaN')
    
    ## then, read the results back to R using readr
    #     summary_records_output <-  readr::read_csv(file = out_file_summary, guess_max = 999999, na = character(), col_types = cols(.default = 'c'))
    #     replicate_records_output <- readr::read_csv(file = out_file_replicate, guess_max = 999999, na = character(), col_types = cols(.default = 'c'))
    # # last, overwrite the original file using readr::write_csv
    #     readr::write_csv(x = summary_records_output, path = out_file_summary, na = 'NaN')
    #     readr::write_csv(x = replicate_records_output, path = out_file_replicate, na = 'NaN')
    
    # # check
    #     summary_check <- readr::read_csv(file = paste0('Toxicity-Summary-Records_', Sys.Date(), '.csv'), guess_max = 500000, na = 'NaN')
    #     replicate_check <- readr::read_csv(file = paste0('Toxicity-Replicate-Records_', Sys.Date(), '.csv'), guess_max = 500000, na = 'NaN')
  },
  error = function(e) {
    error_message <- 'writing output csv files'
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)


# load to CA Data Portal --------------------------------------------------

## summary data ----
# gc()
# tryCatch(
#     {
#         reticulate::py_run_file('C:\\Users\\daltare\\OneDrive - Water Boards\\projects\\CA_data_portal\\Toxicity\\portal-upload-ckan-chunked_Tox\\main_Tox_Summary.py')
#     },
#     error = function(e) {
#         error_message <- 'loading summary data to data.ca.gov portal'
#         error_message_r <- capture.output(cat(as.character(e)))
# vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
#                       pattern = 'ca.epa.local'))
# if (send_failure_email == TRUE) {
#   if (vpn == FALSE) {
#     fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
#   } else {
#     ## attempt to use gmailr if on the VPN
#     fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
#   } 
# }
#         print(glue('Error: {error_message}'))
#         stop(e)
#     }
# )

## replicate data ----
# gc()
# tryCatch(
#     {
#         reticulate::py_run_file('C:\\Users\\daltare\\OneDrive - Water Boards\\projects\\CA_data_portal\\Toxicity\\portal-upload-ckan-chunked_Tox\\main_Tox_Replicate.py')
#     },
#     error = function(e) {
#         error_message <- 'loading replicate data to data.ca.gov portal'
#         error_message_r <- capture.output(cat(as.character(e)))
# vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
#                       pattern = 'ca.epa.local'))
# if (send_failure_email == TRUE) {
#   if (vpn == FALSE) {
#     fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
#   } else {
#     ## attempt to use gmailr if on the VPN
#     fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
#   } 
# }
#         print(glue('Error: {error_message}'))
#         stop(e)
#     }
# )


## python - function ----
tryCatch(
  {
    gc()
    
    ### get the python function ----
    #### install dependent python packages
    setwd(chunked_upload_directory)
    shell('pip install -r requirements.txt')
    setwd('..')
    #### get function
    source_python(python_upload_script)
    
    ### summary data ----
    file_type <- 'Summary'
    print(glue('Updating {file_type} Data'))
    ckanUploadFile(resourceID_summary,
                   out_file_summary,
                   portal_key)
    print(glue('Finished Updating {file_type} Data'))
    gc()
    
    ### replicate data ----
    file_type <- 'Replicate'
    print(glue('Updating {file_type} Data'))
    ckanUploadFile(resourceID_replicate,
                   out_file_replicate,
                   portal_key)
    print(glue('Finished Updating {file_type} Data'))
  },
  error = function(e) {
    error_message <- glue('Uploading data to portal (error occured in uploading the {file_type} Data)')
    error_message_r <- capture.output(cat(as.character(e)))
    vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                          pattern = 'ca.epa.local'))
    if (send_failure_email == TRUE) {
      if (vpn == FALSE) {
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
      } else {
        ## attempt to use gmailr if on the VPN
        fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r)
      } 
    }
    print(glue('Error: {error_message}'))
    stop(e)
  }
)
