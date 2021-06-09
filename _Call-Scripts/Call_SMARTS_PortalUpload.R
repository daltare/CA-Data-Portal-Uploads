# runs the program to upload a csv file to the portal

# NOTE: To schedule this script to run automatically, go to 'Addins' and 'Schedule R scripts on...', then select 
# this file, and set the time/date options (make sure the date format is %m/%d/%Y)

source('C:\\Users\\daltare\\OneDrive - Water Boards\\projects\\CA_data_portal\\SMARTS\\1_FilesList.R') # get information about the files to be retrieved from the SMARTS interface
source('C:\\Users\\daltare\\OneDrive - Water Boards\\projects\\CA_data_portal\\SMARTS\\3_SMARTS_data_portal_automation.R', chdir = TRUE) # runs the program to upload a csv file to the portal
