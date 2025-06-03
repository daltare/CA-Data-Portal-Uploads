# This script just uploads SMARTS data that is saved locally (and has already 
# been processed) to the CA data portal (t is essentially identiacal to the 
# parts of the `SMARTS_data_portal_automation.R` script that are used to upload 
# data to the portal). 

# This script can be used if the download / processing steps of the 
# `SMARTS_data_portal_automation.R` script succeed but the upload(s) to the CA 
# data portal fail - i.e., the purpose of this script is to easily re-try the 
# data portal uploads, which regularly fail for various reasons that are somewhat
# difficult to diagnose and fix.

# load packages -----------------------------------------------------------
{
    library(RSelenium)
    library(methods) # it seems that this needs to be called explicitly to avoid an error for some reason
    library(XML)
    library(tidyverse)
    library(janitor)
    library(lubridate)
    library(glue)
    library(sendmailR)
    library(blastula)
    library(binman)
    library(pingr)
    library(ckanr)
    library(wdman)
    library(here)
    library(reticulate)
    
    ## conflicts
    library(conflicted)
    conflicts_prefer(dplyr::filter)
}



# user input --------------------------------------------------------------
{
    ## set download directory ----
    ##(i.e., where to save any downloaded files)
    download_dir <- 'C:/Users/daltare/Documents/ca_data_portal_temp/SMARTS/'
    
    ## delete old files
    delete_old_versions = TRUE # whether or not to delete previous versions of each dataset - FALSE means to keep the old versions
    # NOTE: currently set to keep the versions from the previous 7 days if TRUE
    
    ## enter the email address to send warning emails from
    ### NOTE - if sending from a personal email address, you'll have to update the credentials -- see below
    email_from <- 'daltare.swrcb@gmail.com' # 'david.altare@waterboards.ca.gov' # "gisscripts-noreply@waterboards.ca.gov"
    
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
    credentials_file <- 'gmail_creds' # this is the credentials file to be used (corresponds to the email_from address)
    
    ## enter the email address (or addresses) to send warning emails to ----
    email_to <- 'david.altare@waterboards.ca.gov' # c('david.altare@waterboards.ca.gov', 'waterdata@waterboards.ca.gov')
    
    ## get data portal API key (saved in the local environment) ----
    ### (it's available on data.ca.gov by going to your user profile)
    portal_key <- Sys.getenv('data_portal_key')
    
    ## define location of python script to upload chunked data (relative path)
    python_upload_script <- here('portal-upload-ckan-chunked_SMARTS', 
                                 'main_SMARTS_function.py')
    # chunked_upload_directory <- here('portal-upload-ckan-chunked_SMARTS')
    
    ## set times for Sys.sleep() arguments
    sleep_time <- 0.5
}


# enter info about datasets to be downloaded ------------------------------
## The filename is the name of the file that will be output (the current date will also be appended to the name) - using the tile of the link to the dataset on the SMARTS webpage as the filename, to make it easier to keep track of the data source
## The html_id is the identifier of the button/link for the given dataset in the html code on the SMARTS website (use the 'developer' too in the browser to find this in the html code)
dataset_list <- list(dataset1 = list(filename = 'Industrial_Ad_Hoc_Reports_-_Parameter_Data', 
                                     html_id = 'intDataFileDowloaddataFileForm:industrialRawDataLink',
                                     resource_id = '7871e8fe-576d-4940-acdf-eca0b399c1aa',
                                     date_fields = c('SAMPLE_DATE', 'DISCHARGE_START_DATE'), # NOTE: The number of items in this field should be the same as the number of items in the following two fields
                                     time_fields = c('SAMPLE_TIME', 'DISCHARGE_START_TIME'),
                                     timestamp_names = c('SAMPLE_TIMESTAMP', 'DISCHARGE_START_TIMESTAMP'),
                                     numeric_fields = c('REPORTING_YEAR', 'MONITORING_LATITUDE', 
                                                        'MONITORING_LONGITUDE', 'RESULT', 
                                                        'MDL', 'RL')),
                     dataset2 = list(filename = 'Industrial_Application_Specific_Data', 
                                     html_id = 'intDataFileDowloaddataFileForm:industrialAppLink',
                                     resource_id = '33e69394-83ec-4872-b644-b9f494de1824',
                                     date_fields = c('NOI_PROCESSED_DATE', 'NOT_EFFECTIVE_DATE', 'CERTIFICATION_DATE'), # NOTE: The number of items in this field should be the same as the number of items in the following two fields
                                     time_fields = c('', '', ''),
                                     timestamp_names = c('NOI_PROCESSED_TIMESTAMP', 'NOT_EFFECTIVE_TIMESTAMP', 'CERTIFICATION_TIMESTAMP'),
                                     numeric_fields = c('FACILITY_LATITUDE', 'FACILITY_LONGITUDE', 
                                                        'FACILITY_TOTAL_SIZE', 'FACILITY_AREA_ACTIVITY', 
                                                        'PERCENT_OF_SITE_IMPERVIOUSNESS')),
                     dataset3 = list(filename = 'Construction_Ad_Hoc_Reports_-_Parameter_Data', 
                                     html_id = 'intDataFileDowloaddataFileForm:constructionAdhocRawDataLink',
                                     resource_id = '0c441948-5bb9-4d50-9f3c-ca7dab256056', 
                                     date_fields = c('SAMPLE_DATE', 'EVENT_START_DATE', 'EVENT_END_DATE'), # NOTE: The number of items in this field should be the same as the number of items in the following two fields
                                     time_fields = c('SAMPLE_TIME', '', ''),
                                     timestamp_names = c('SAMPLE_TIMESTAMP', 'EVENT_START_TIMESTAMP', 'EVENT_END_TIMESTAMP'),
                                     numeric_fields = c('REPORT_YEAR', 'RAINFALL_AMOUNT', 
                                                        'BUSINESS_DAYS', 'MONITORING_LATITUDE', 
                                                        'MONITORING_LONGITUDE', 'PERCENT_OF_TOTAL_DISCHARGE', 
                                                        'RESULT', 'MDL', 'RL')),    
                     dataset4 = list(filename = 'Construction_Application_Specific_Data', 
                                     html_id = 'intDataFileDowloaddataFileForm:constructionAppLink',
                                     resource_id = '8a0ed456-ca69-4b29-9c5b-5de3958dc963', 
                                     date_fields = c('NOI_PROCESSED_DATE', 'NOT_EFFECTIVE_DATE', 'CERTIFICATION_DATE',
                                                     'CONSTRUCTION_COMMENCEMENT_DATE', 'COMPLETE_GRADING_DATE', 'COMPLETE_PROJECT_DATE'), # NOTE: The number of items in this field should be the same as the number of items in the following two fields
                                     time_fields = c('', '', '', '', '', ''),
                                     timestamp_names = c('NOI_PROCESSED_TIMESTAMP', 'NOT_EFFECTIVE_TIMESTAMP', 'CERTIFICATION_TIMESTAMP',
                                                         'CONSTRUCTION_COMMENCEMENT_TIMESTAMP', 'COMPLETE_GRADING_TIMESTAMP', 'COMPLETE_PROJECT_TIMESTAMP'),
                                     numeric_fields = c('SITE_LATITUDE', 'SITE_LONGITUDE', 
                                                        'SITE_TOTAL_SIZE', 'SITE_TOTAL_DISTURBED_ACREAGE', 
                                                        'PERCENT_TOTAL_DISTURBED', 'IMPERVIOUSNESS_BEFORE', 
                                                        'IMPERVIOUSNESS_AFTER', 'R_FACTOR', 
                                                        'K_FACTOR', 'LS_FACTOR', 
                                                        'WATERSHED_EROSION_ESTIMATE')),
                     dataset5 = list(filename = 'Inspections', 
                                     html_id = 'intDataFileDowloaddataFileForm:inspectionLink',
                                     resource_id = '33047e47-7d44-46aa-9e0f-1a0f1b0cad66',
                                     date_fields = c('INSPECTION_DATE'),
                                     time_fields = c('INSPECTION_START_TIME', 'INSPECTION_END_TIME'),
                                     timestamp_fields = c(),
                                     numeric_fields = c('COUNT_OF_VIOLATIONS', 'PLACE_LATITUDE', 
                                                        'PLACE_LONGITUDE', 'PLACE_TOTAL_SIZE')),
                     dataset6 = list(filename = 'Violations', 
                                     html_id = 'intDataFileDowloaddataFileForm:violationLink',
                                     resource_id = '9b69a654-0c9a-4865-8d10-38c55b1b8c58',
                                     date_fields = c('OCCURRENCE_DATE', 'DISCOVERY_DATE'),
                                     time_fields = c(),
                                     timestamp_fields = c(),
                                     numeric_fields = c('PLACE_LATITUDE', 'PLACE_LONGITUDE', 'PLACE_TOTAL_SIZE')),
                     dataset7 = list(filename = 'Enforcement_Actions', 
                                     html_id = 'intDataFileDowloaddataFileForm:enfocementActionLink',
                                     resource_id = '9cf197f4-f1d5-4d43-b94b-ccb155ef14cf',
                                     date_fields = c('ISSUANCE_DATE', 'DUE_DATE', 'ACL_COMPLAINT_ISSUANCE_DATE', 
                                                     'ADOPTION_DATE', 'COMPLIANCE_DATE', 'EPL_ISSUANCE_DATE', 
                                                     'RECEIVED_DATE', 'WAIVER_RECEIVED_DATE'),
                                     time_fields = c(),
                                     timestamp_fields = c(),
                                     numeric_fields = c('ECONOMIC_BENEFITS', 'TOTAL_MAX_LIABILITY', 'STAFF_COSTS', 
                                                        'INITIAL_ASSESSMENT', 'TOTAL_ASSESSMENT', 'RECEIVED_AMOUNT', 
                                                        'SPENT_AMOUNT', 'BALANCE_DUE', 'COUNT_OF_VIOLATIONS', 
                                                        'PLACE_LATITUDE', 'PLACE_LONGITUDE', 'PLACE_TOTAL_SIZE'))
)





# load data to portal -----------------------------------------------------

## run function to upload the formatted data from SMARTS to the data.ca.gov portal ----
### loops through all of the datasets defined in the 'dataset_list' variable in the script: 1_FilesList.R

print('Uploading datasets to the CA open data portal (data.ca.gov)')

# ### set the ckan defaults ----
# ckanr_setup(url = 'https://data.ca.gov/', key = portal_key)

### get the python function ----
python_path <- reticulate::py_config()$pythonhome
reticulate::use_python(python = python_path, # required to run as scheduled task - see: https://stackoverflow.com/a/70067336
                       required = T)

#### install dependent python packages
# setwd(chunked_upload_directory)
# shell('pip install -r requirements.txt')
# setwd('..')
#### get function
reticulate::source_python(python_upload_script)

for (i in seq(length(dataset_list))) {
    resourceID <- dataset_list[[i]]$resource_id
    filename <- dataset_list[[i]]$filename
    
    print(glue('Uploading file: {filename}'))
    
    # ckan_resource_info <- resource_show(id = resourceID, as = 'table') # resource
    # check the connection
    # current_dataportal_filename <- gsub(pattern = '.*/download/', replacement = '', x = ckan_resource_info$url)
    # print(current_dataportal_filename) # this is just a test to make sure the API connection is successful
    
    fileToUpload <- paste0(download_dir, filename, '_', Sys.Date(), '.csv')
    
    # file_upload <- resource_update(id = resourceID, path = fileToUpload)
    
    ckanUploadFile(resourceID,
                   fileToUpload,
                   portal_key)
    
    print(glue('Finished Updating {filename}\n'))
    
    Sys.sleep(1)
    
    # # output the result of the upload process to a log file called: _DataPortalUpload-Log.txt
    # # check to see if the log file exists - if not, create it
    # if (file.exists('_DataPortalUpload-Log.txt') == FALSE) {
    #     file.create('_DataPortalUpload-Log.txt')
    # }
    # # write the result to the log file, depending on the current data portal filename
    # file_name_check <- paste0(filename, '_', Sys.Date(), '.csv')
    # new_dataportal_filename <- gsub(pattern = '.*/download/', replacement = '', x = file_upload$url)
    # if (tolower(new_dataportal_filename) == tolower(file_name_check)) {
    #     write_lines(x = paste0(Sys.time(), ' - ', file_name_check, ': ', 'Completed Upload'), 
    #                 file = '_DataPortalUpload-Log.txt', append = TRUE)   
    # } else {
    #     write_lines(x = paste0(Sys.time(), ' - ', file_name_check, ': ', 'Upload NOT completed'), 
    #                 file = '_DataPortalUpload-Log.txt', append = TRUE)
    # }
}
print('Upload complete')

