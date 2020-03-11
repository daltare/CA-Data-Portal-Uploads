# For automated updates, turn off by setting run_script to FALSE
    run_script <- TRUE
    if(run_script == TRUE) {
        
    # NOTE: To schedule this script to run automatically, go to 'Addins' and 'Schedule R scripts on...', then select 
    # the file that calls this script ("C:\\David\\Open_Data_Project\\__CA_DataPortal\\_Call_Scripts\\Call_SurfWater_Script.R.R")
    # and set the time/date option (make sure the date format is %m/%d/%Y)


library(odbc) # for working with databases
library(DBI) # for working with databases
library(dplyr)
library(lubridate)
library(stringr)
library(ckanr) # for working with CKAN data portal
library(readr)


# define data portal resource IDs for the summary and replicate records
    resourceID_summary <- '674474eb-e093-42de-aef3-da84fd2ff2d8' # https://data.ca.gov/dataset/surface-water-toxicity-results/resource/674474eb-e093-42de-aef3-da84fd2ff2d8
    resourceID_replicate <- '6fd7b8d7-f8dd-454f-98bb-07e8cc710db8' # https://data.ca.gov/dataset/surface-water-toxicity-results/resource/6fd7b8d7-f8dd-454f-98bb-07e8cc710db8

# SQL Server Connections ----
    # References
        # https://rviews.rstudio.com/2017/05/17/databases-using-r/
        # https://support.rstudio.com/hc/en-us/articles/214510788-Setting-up-R-to-connect-to-SQL-Server-
        # http://db.rstudio.com/odbc/
        # https://rdrr.io/cran/RODBC/man/odbcClose.html
        # https://cran.r-project.org/web/packages/odbc/odbc.pdf

    # get user ID and Password for CEDEN Data Mart
        dm.user <- Sys.getenv('UID')
        dm.password <- Sys.getenv('PWD')

    # CEDEN Database connection
        # set up the connection
            con_CEDEN <- dbConnect(odbc(),
                                   Driver = "SQL Server",
                                   #Server = "172.22.33.39, 2866",
                                   Server = "172.22.33.38, 1541",
                                   Database = "DataMarts",
                                   UID = dm.user, 
                                   PWD = dm.password, 
                                   Port = 1433)
        
# Query Database ----
    # NOTE: There are two different methods in this script to retrieve the data and sort into summary vs replicate records -- only need to do one, not both (they should give the same result)
        # # METHOD 1 - Read all data from the database, then sort by summary or replicate records within R
        #     # read all data
        #         WebSvc_Tox <- dbReadTable(con_CEDEN, 'WebSvc_Tox')
        #         
        #     # Close connection 
        #         dbDisconnect(con_CEDEN)
        #     
        #     # Subset data to select summary or replicate records only ----
        #     # Required fields for summary records -- RepCount, Mean, StdDev, StatMethod, AlphaLevel, Probability, CriticalValue, PctControl, EvalThreshold, SigEffectCode
        #     # Optional fields for summary records -- bValue, CalcValueType, PercentEffect, MSD, ToxPointSummaryComments
        #         summary.records.tf <- !is.na(WebSvc_Tox$RepCount) | 
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
        #         summary.records <- WebSvc_Tox[summary.records.tf, ]
        #         replicate.records <- WebSvc_Tox[!summary.records.tf, ]
        
        # METHOD 2 - Query for either summary or replicate records, using SQL statements
            # run queries and import the result to R
            # All records
                query_CEDEN_all <- dbSendQuery(con_CEDEN, "SELECT * FROM WebSvc_Tox")
                all.records <- dbFetch(query_CEDEN_all)
                all.records.count <- nrow(all.records)
                # rm(list = c('all.records'))  
            # Summary Records
                query_CEDEN_summary <- dbSendQuery(con_CEDEN, "SELECT * FROM WebSvc_Tox WHERE 
                                                    Mean IS NOT NULL AND
                                                    StdDev IS NOT NULL AND
                                                    StatMethod IS NOT NULL AND
                                                    AlphaLevel IS NOT NULL AND
                                                    Probability IS NOT NULL AND
                                                    CriticalValue IS NOT NULL AND
                                                    PctControl IS NOT NULL AND
                                                    EvalThreshold IS NOT NULL AND
                                                    SigEffectCode IS NOT NULL")
                summary.records <- dbFetch(query_CEDEN_summary)#, n = 1000)
                summary.records <- summary.records %>% mutate(SampleDate = as.Date(SampleDate))
                summary.records_distinct <- summary.records %>% select(-c('ToxID', 'LabReplicate', 'Result', 'ResQualCode', 'ToxResultComments', 'OrganismPerRep', 'ToxResultQACode')) %>% distinct()
                summary.records_distinct_noQA <- summary.records_distinct %>% filter(StationCode != 'LABQA_SWAMP')
            # Replicate Records
                # Method to find replicate records:
                    # start with all records
                    # drop the 9 fields used in the query to get summary records
                    # drop ToxID field (just a unique ID for each row in the database)
                    # drop ToxPoint_MatrixName - this field is not included in the Replicate data exported to data.ca.gov, but it there are replicate records which are identical except for this field (so retaining this field would cause duplicates when the fields not included in the replicate data are dropped)
                    # drop records where LabReplicate is NA
                    # select just the distinct records
                    # drop records where StationCode is"LABQA_SWAMP" to get non-QA records
                # Get the Replicates
                replicate.records <- all.records %>% 
                    select(-c('Mean', 'StdDev', 'StatMethod', 'AlphaLevel', 'Probability', 
                              'CriticalValue', 'PctControl', 'EvalThreshold', 'SigEffectCode')) %>% 
                    select(-c('ToxID')) %>% 
                    select(-c('ToxPoint_MatrixName')) %>% 
                    filter(!is.na(LabReplicate))
                replicate.records_distinct <- replicate.records %>% distinct()
                replicate.records_noQA <- replicate.records %>% filter(StationCode != 'LABQA_SWAMP')
                replicate.records_noQA_distinct <- replicate.records_noQA %>% distinct()
                # check to see if there are any non-distinct records after the query to get the replicates
                # result of the operation should be zero if all records are distinct
                    # nrow(replicate.records) - nrow(replicate.records_distinct)
                    # nrow(replicate.records_noQA) - nrow(replicate.records_noQA_distinct)
                
                # # As a check, look at LabReplicate, and Result - if these are NA (or some other related value) it may indicate a summary record
                #     # Look at cases where there are summary records (defined by the 9 fields) but the LabReplicate is NA or -88
                #         table(summary.records$LabReplicate, useNA = 'ifany') # there are 20168 "NA" and 178 "-88"
                #     # Look at cases where there are summary records but no Result value
                #         min(summary.records$Result, na.rm = TRUE)
                #         sum(summary.records$Result == -88, na.rm = TRUE) # 65 records where result is -88
                #         sum(is.na(summary.records$Result)) # 23364 records where result is NA
                #     summary.records_LabRepNA <- summary.records %>% filter(is.na(LabReplicate) & StationCode != 'LABQA_SWAMP')
                #         View(summary.records_LabRepNA)
                #         sum(is.na(summary.records_LabRepNA$Result)) # 17374 -- All of these records are missing a result value too - can probably get rid of them
                #     summary.records_LabRep88 <- summary.records %>% filter(LabReplicate == -88)
                #         sum(is.na(summary.records_LabRep88$Result)) # 5
                #         table(summary.records_LabRep88$Result, useNA = 'ifany') # most of these have a distinct result
                #         View(summary.records_LabRep88)
                #     summary.records_ResultNA <- summary.records %>% filter(is.na(Result) & StationCode != 'LABQA_SWAMP' & !is.na(LabReplicate) & LabReplicate != -88)
                #         View(summary.records_ResultNA)
                #         table(summary.records_ResultNA$LabReplicate, useNA = 'ifany') # probably want to retain these values where result is NA since there are associated LabReplicate numbers for some
                
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
                # replicate.records_Old <- dbFetch(query_CEDEN_replicate)#, n = 1000)
                # replicate.records_Old <- replicate.records_Old %>% mutate(SampleDate = as.Date(SampleDate))
          
            # Close connection 
                dbDisconnect(con_CEDEN)
                
            # check -- number of records
                # nrow(replicate.records) + nrow(summary.records) - all.records.count # should be zero - means all records in the database are within one of the two datasets

        # # check
        #     View(summary.records %>% select(Mean, StdDev, StatMethod, AlphaLevel, Probability, CriticalValue, PctControl, EvalThreshold, SigEffectCode))
        #     View(replicate.records %>% select(Mean, StdDev, StatMethod, AlphaLevel, Probability, CriticalValue, PctControl, EvalThreshold, SigEffectCode))
 
                           
# NAMES - get a list of the names used in the tox data entry template, and the corresponding names used in the CEDEN database (for more info, see the workbook called: Mapping_Fields_ToxTemplateToWebServices.xls) ----    
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
                                  'Probability', 'CriticalValue', 'PctControl', 'MSD', 'EvalThreshold', 
                                  'SigEffectCode', 'QACode', 'ComplianceCode', 'ToxPointSummaryComments', 'TIENarrative', 
                                  'Program', 'ParentProject', 'TargetLatitude', 'TargetLongitude', 'Datum', 
                                  'PctControl', 'ToxBatch', 'ToxBatchStartDate', 'LabAgency', 'LabSubmissionCode', 
                                  'BatchVerificationCode', 'RefToxBatch', 'OrganismAgeAtTestStart', 'SubmittingAgency', 'OrganismSupplier', 
                                  'ToxBatchComments')
        tf_duplicated <- duplicated(summary_records_db_names)
        summary_records_db_names <- summary_records_db_names[!tf_duplicated]
    summary_records_template_names <- c('StationCode', 'SampleDate', 'ProjectCode', 'EventCode', 'ProtocolCode', 
                                        'AgencyCode', 'SampleComments', 'LocationCode', 'GeometryShape', 'CollectionTime', 
                                        'CollectionMethodCode', 'SampleTypeCode', 'Replicate', 'CollectionDeviceName', 'CollectionDepth', 
                                        'UnitCollectionDepth', 'PositionWaterColumn', 'LabCollectionComments', 'ToxBatch', 'MatrixName', 
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
        
# Format Records ----
    # define which data frame to use as the output
        summary.records_output <- summary.records_distinct
        replicate.records_output <- replicate.records_distinct
    # select just the relevant fields for the output
        # summary
        summary.records_output <- summary.records_output %>% select(summary_records_db_names)
        names(summary.records_output) <- summary_records_template_names
        # replicate
        replicate.records_output <- replicate.records_output %>% select(replicate_records_db_names)
        names(replicate.records_output) <- replicate_records_template_names
    # make sure the output records are still distinct
        # summary
        summary.records_output_check <- summary.records_output %>% distinct()
            nrow(summary.records_output) - nrow(summary.records_output_check) # should be zero
        # replicate
        replicate.records_output_check <- replicate.records_output %>% distinct()
            nrow(replicate.records_output) - nrow(replicate.records_output_check) # should be zero

        # The code below was used to check which fields contain distinct values which are not included in the final output, and would result in duplicates when the un-used fields are dropped
            # nrow(summary.records_output) - nrow(summary.records_output_check)
            # z_summary_dup <- duplicated(summary.records_output) | duplicated(summary.records_output, fromLast = TRUE)
            # sum(z_summary_dup)
            # z_summary_dup <- summary.records_output[z_summary_dup,]
            # View(z_summary_dup)
            # z_summary_dup_2 <- z_summary_dup %>% filter(StationCode == z_summary_dup$StationCode[1])
            # View(z_summary_dup_2)
            # zzz <-  summary.records_distinct %>% filter(StationCode == z_summary_dup_2$StationCode[1] & SampleDate == z_summary_dup_2$SampleDate[1] & Analyte == z_summary_dup_2$AnalyteName[1] & ToxBatch == z_summary_dup_2$ToxBatch[1]) %>% distinct()
            # View(zzz)
            
            # nrow(replicate.records_output) - nrow(replicate.records_output_check)
            # z_replicate_dup <- duplicated(replicate.records_output) | duplicated(replicate.records_output, fromLast = TRUE)
            # sum(z_replicate_dup)
            # z_replicate_dup <- replicate.records_output[z_replicate_dup,]
            # View(z_replicate_dup)
            # z_replicate_dup_2 <- z_replicate_dup %>% filter(StationCode == z_replicate_dup$StationCode[1])
            # View(z_replicate_dup_2)
            # zzz <-  replicate.records_distinct %>% filter(StationCode == z_replicate_dup_2$StationCode[1] & SampleDate == z_replicate_dup_2$SampleDate[1] & Analyte == z_replicate_dup_2$AnalyteName[1] & ToxBatch == z_replicate_dup_2$ToxBatch[1] & TimePointName == z_replicate_dup_2$TimePoint[1]) %>% distinct()
            # View(zzz)
       
            
# check dataset for portal compatibility and adjust as needed  ----  
    # summary records ----
            dplyr::glimpse(summary.records_output)
            
            # fix collection time field
                summary.records_output <- summary.records_output %>% 
                    mutate(CollectionTime = paste(sep = ':',
                                                  str_pad(hour(x = summary.records_output$CollectionTime),width = 2, pad = 0),
                                                  str_pad(minute(x = summary.records_output$CollectionTime),width = 2, pad = 0),
                                                  str_pad(second(x = summary.records_output$CollectionTime),width = 2, pad = 0)))
            
            # date fields - convert dates into a timestamp field that can be read by the portal
                fields_dates <- c('SampleDate', 'StartDate')
                for (counter in seq(length(fields_dates))) {
                    # convert the date field to ISO format
                        dates_iso <- ymd(as.Date(summary.records_output[[fields_dates[counter]]]))
                            # check NAs: sum(is.na(dates_iso))
                    # Convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
                        dates_iso <- as.character(dates_iso)
                            # Check: sum(is.na(dates_iso))
                        dates_iso[is.na(dates_iso)] <- ''
                            # check NAs: sum(is.na(dates_iso))
                    # Insert the revised date field back into the dataset
                        summary.records_output[,fields_dates[counter]] <- dates_iso
                }
            
            # numeric fields - ensure all records are compatible with numeric format 
                fields_numeric <- c('Replicate', 'CollectionDepth', 'Concentration', 'Dilution', 'RepCount', 
                                    'Mean', 'StdDev', 'AlphaValue', 'bValue', 'CalculatedValue',
                                    'CriticalValue', 'PercentEffect', 'MSD', 'EvalThreshold', 'Lat',
                                    'Long')
                # convert to numeric
                    for (counter in seq(length(fields_numeric))) {
                        summary.records_output[,fields_numeric[counter]] <- as.numeric(summary.records_output[[fields_numeric[counter]]])
                    }
            
            # Convert missing values in text fields to 'NA' (to avoid converting to NaN) !!!!!!!!!!!
            # from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
                summary.records_output <- summary.records_output %>% mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))
                
    # replicate records ----
        dplyr::glimpse(replicate.records_output)
    
        # fix collection time field
            replicate.records_output <- replicate.records_output %>% 
                mutate(CollectionTime = paste(sep = ':',
                                              str_pad(hour(x = replicate.records_output$CollectionTime),width = 2, pad = 0),
                                              str_pad(minute(x = replicate.records_output$CollectionTime),width = 2, pad = 0),
                                              str_pad(second(x = replicate.records_output$CollectionTime),width = 2, pad = 0)))
    
        # date fields - convert dates into a timestamp field that can be read by the portal
            fields_dates <- c('SampleDate', 'StartDate')
            for (counter in seq(length(fields_dates))) {
                # convert the date field to ISO format
                    dates_iso <- ymd(as.Date(replicate.records_output[[fields_dates[counter]]]))
                        # check NAs: sum(is.na(dates_iso))
                # Convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
                    dates_iso <- as.character(dates_iso)
                        # Check: sum(is.na(dates_iso))
                    dates_iso[is.na(dates_iso)] <- ''
                        # check NAs: sum(is.na(dates_iso))
                # Insert the revised date field back into the dataset
                    replicate.records_output[,fields_dates[counter]] <- dates_iso
            }
    
        # numeric fields - ensure all records are compatible with numeric format 
            fields_numeric <- c('Replicate', 'CollectionDepth', 'Concentration', 'Dilution', 'LabReplicate', 'Result', 
                                'Lat', 'Long')
            # convert to numeric
                for (counter in seq(length(fields_numeric))) {
                    replicate.records_output[,fields_numeric[counter]] <- as.numeric(replicate.records_output[[fields_numeric[counter]]])
                }
    
        # Convert missing values in text fields to 'NA' (to avoid converting to NaN) !!!!!!!!!!!
        # from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
            replicate.records_output <- replicate.records_output %>% mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))
    
                
# Write CSV Files (Note: have to do multiple steps to fix encoding) ----
    # define output filenames
        out_file_summary <- paste0('Toxicity-Summary-Records_', Sys.Date(), '.csv')
        out_file_replicate <- paste0('Toxicity-Replicate-Records_', Sys.Date(), '.csv')
    # # first write to file using base write.csv, and specify encoding
        write.csv(x = summary.records_output, file = out_file_summary, row.names = FALSE, fileEncoding = 'UTF-8', na = 'NaN')
        write.csv(x = replicate.records_output, file = out_file_replicate, row.names = FALSE, fileEncoding = 'UTF-8', na = 'NaN')
    # # then, read the results back to R using readr
    #     summary.records_output <-  readr::read_csv(file = out_file_summary, guess_max = 999999, na = character(), col_types = cols(.default = 'c'))
    #     replicate.records_output <- readr::read_csv(file = out_file_replicate, guess_max = 999999, na = character(), col_types = cols(.default = 'c'))
    # # last, overwrite the original file using readr::write_csv
    #     readr::write_csv(x = summary.records_output, path = out_file_summary, na = 'NaN')
    #     readr::write_csv(x = replicate.records_output, path = out_file_replicate, na = 'NaN')
    
# # check
#     summary.check <- readr::read_csv(file = paste0('Toxicity-Summary-Records_', Sys.Date(), '.csv'), guess_max = 500000, na = 'NaN')
#     replicate.check <- readr::read_csv(file = paste0('Toxicity-Replicate-Records_', Sys.Date(), '.csv'), guess_max = 500000, na = 'NaN')
    
# Load to the CA Data Portal ----
    # get the data portal API key saved in the local environment (to change these, search Windows for 'Edit environment variables for your account')
        # API key is available on data.ca.gov by going to your user profile)
        portal_key <- Sys.getenv('data_portal_key')
    # set the ckan defaults    
        ckanr_setup(url = 'https://data.ca.gov/', key = portal_key)    
    # Summary Results
        # get resource info (just as a check)
            ckan_resource_info <- resource_show(id = resourceID_summary, as = 'table')
        # write to the portal
            file_upload <- ckanr::resource_update(id = resourceID_summary, path = out_file_summary)
    # Replicate Results
        # get resource info (just as a check)
            ckan_resource_info <- resource_show(id = resourceID_replicate, as = 'table')
        # write to the portal
            file_upload <- ckanr::resource_update(id = resourceID_replicate, path = out_file_replicate)
                
}