# runs the program to upload a csv file to the portal

# NOTE: To schedule this script to run automatically, go to 'Addins' and 'Schedule R scripts on...', then select 
# this file, and set the time/date options (make sure the date format is %m/%d/%Y)

# source('C:/David/Open_Data_Project/__CA_DataPortal/Toxicity/Summary-Replicate-Results/Toxicity-Summary-Replicate-Data-Pull.R', chdir = TRUE) # runs the program to upload a csv file to the portal
reticulate::py_run_file('C:\\Users\\daltare\\OneDrive - Water Boards\\projects\\CA_data_portal\\Toxicity\\portal-upload-ckan-chunked_Tox\\main_Tox_Summary.py')
