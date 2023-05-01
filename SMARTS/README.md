# Instructions - SMARTS Open Data Portal Updates

The only required step is to run the `SMARTS_data_portal_automation.R` script (i.e., run `source('SMARTS_data_portal_automation.R')` or open the file in RStudio and click the `Source` button). This should handle all parts of the update process - some parts of the process will call other scripts, including `start_selenium.R`.

To automatically run the process on a set schedule on a Windows computer, you can create a task in "Task Scheduler" that runs the `Call_SMARTS.bat` file (which is in the `_Call-Scripts` directory at the top level of this repository) on a specified day and time.

If the process fails at any point, it is set up to send an automated email alerting you that it has failed (and an attempt at telling you why it failed).

There are a few additional things to be aware of, which will likely require some set-up work before the first time the update process is run by a new user (or on a new computer):

-   To get an automated email with an alert when the process fails, you'll need to modify some variables in the `1 - user input` part of the `1_ceden_automate.R` script (including the `email_from`, `email_to`, and `credentials_file` variables), and create a new email credentials file (instructions for creating the credentials file are also in the `1 - user input` part of the script).

-   The process assumes that you have an account on the data.ca.gov portal (with rights to edit datasets managed by the [California State Water Resources Control Board](https://data.ca.gov/organization/california-state-water-resources-control-board) organizational account), and that you have the necessary credentials saved as Environment Variables on your computer (in Windows, search for "edit environment variables for your account"), which are accessed in the `1 - user input` part of the script. The variables are:

    -   `data_portal_key`: API key for your personal data.ca.gov account (available on data.ca.gov by going to your user profile)

-   The process (optionally) saves data files to a separate directory (i.e., not necessarily the one in which this project is stored). This separate directory is defined by the `download_dir` variable, and needs to be edited to run the script on a different computer. (As a side note, it's set up this way because, for my own use, I have the project saved to OneDrive, but I don't want to frequently save a lot of large files to a cloud location like OneDrive, so instead save them to the local C drive.)

Finally, if you ever need to update the data dictionary for any resource, you can use the `stormwater_data-dictionary-tool.R` script in the `Data_Dictionaries` folder to automate the process.