# NOTE: To schedule this script to run automatically, go to 'Addins' and 'Schedule R scripts on...', then select 
# the file that calls this script ("C:\\David\\Open_Data_Project\\__CA_DataPortal\\_Call_Scripts\\_Call_SMARTS_PortalUpload.R")
# and set the time/date option (make sure the date format is %m/%d/%Y)

# set the download directory (i.e., where downloaded files are saved)
    download_dir <- 'C:\\David\\_CA_data_portal\\SMARTS'

# STEP 1: Set up the information to make the connection to the data.ca.gov portal ----
    # get the data portal API key saved in the local environment (it's available on data.ca.gov by going to your user profile)
        portal_key <- Sys.getenv('data_portal_key')
    # set the ckan defaults    
        ckanr::ckanr_setup(url = 'https://data.ca.gov/', key = portal_key)

    # Load libraries
        library(readr)
    
# STEP 2: Run the function to upload the formatted data from SMARTS to the data.ca.gov portal - loop through all of the datasets defined in the 'dataset_list' variable in the script: 1_FilesList.R  ----
        for (i in seq(length(dataset_list))) {
            # WRITE THE FORMATTED FILE TO THE CA DATA PORTAL, USING THE R PACKAGE THAT INTERFACES WITH THE REST API ####
                resourceID <- dataset_list[[i]]$resource_id
                filename <- dataset_list[[i]]$filename
                ckan_resource_info <- ckanr::resource_show(id = resourceID, as = 'table') # resource
                # check the connection
                    # current_dataportal_filename <- gsub(pattern = '.*/download/', replacement = '', x = ckan_resource_info$url)
                    # print(current_dataportal_filename) # this is just a test to make sure the API connection is successful
                fileToUpload <- paste0(download_dir, '\\', filename, '_', Sys.Date(), '.csv')
                file_upload <- ckanr::resource_update(id = resourceID, path = fileToUpload)
                
            # output the result of the upload process to a log file called: _DataPortalUpload-Log.txt
                # check to see if the log file exists - if not, create it
                    if (file.exists('_DataPortalUpload-Log.txt') == FALSE) {
                        file.create('_DataPortalUpload-Log.txt')
                    }
                # write the result to the log file, depending on the current data portal filename
                    new_dataportal_filename <- gsub(pattern = '.*/download/', replacement = '', x = file_upload$url)
                    if (tolower(new_dataportal_filename) == tolower(fileToUpload)) {
                        write_lines(x = paste0(Sys.time(), ' - ', fileToUpload, ': ', 'Completed Upload'), 
                                    file = '_DataPortalUpload-Log.txt', append = TRUE)   
                    } else {
                        write_lines(x = paste0(Sys.time(), ' - ', fileToUpload, ': ', 'Upload NOT completed'), 
                                    file = '_DataPortalUpload-Log.txt', append = TRUE)
                    }
        }