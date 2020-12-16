shell.exec(file = 'C:/David/Stormwater/_SMARTS_Data_Download_Automation/Start_Server.bat') # this sets up the selenium server - see the R script for more info on how this was created
source('C:/David/Stormwater/_SMARTS_Data_Download_Automation/1_FilesList.R') # get information about the files to be retrieved from the SMARTS interface
source('C:/David/Stormwater/_SMARTS_Data_Download_Automation/2_SMARTS_data_download_automation.R', chdir = TRUE) # downloads the data from SMARTS to a local csv file
shell.exec(file = 'C:/David/Stormwater/_SMARTS_Data_Download_Automation/Stop.bat') # this closes the java window
