# Instructions - Water Conservation Open Data Portal Updates

This script automates the process of loading data from the [Waterboard's conservation portal](http://www.waterboards.ca.gov/water_issues/programs/conservation_portal/conservation_reporting.shtml) onto the [Drinking Water - Public Water System Operations Monthly Water Production and Conservation Information](https://data.ca.gov/dataset/drinking-water-%E2%80%93-urban-water-supplier-monitoring-%E2%80%93-drinc) dataset on the CA Open Data Portal. It pulls the most recent dataset from the Waterboard's site and checks to see if that dataset has already been loaded to the CA data portal. If not, it does a bit of reformatting (including renaming and reordering columns, replacing blanks with NAs, and inserting the PWSID codes), saves the reformatted dataset locally as a .csv file, and pushes the reformatted .csv file to the data.ca.gov portal.

The only required step is to run the `UrbanWaterSupplier_Automated.R` script (e.g., run `source('UrbanWaterSupplier_Automated.R')` or open the file in RStudio and click the `Source` button). This should handle all parts of the update process.

To automatically run this update process on a set schedule on a Windows computer, you can create a task in "Task Scheduler" that runs the `Call_UrbanSupplierConservation.bat` file on a specified day and time (the `Call_UrbanSupplierConservation.bat` file is in the `_Call-Scripts` directory at the top level of this repository).

If the processes fail at any point, they are set up to send an automated email alerting you that the process has failed (and an attempt at telling you why it failed).

There are a few additional things to be aware of, which will likely require some set-up work before the first time the update process is run by a new user (or on a new computer):

-   To get an automated email with an alert when the process fails, you'll need to modify some variables in the `1 - user inputs` part of the script (including the `email_from`, `email_to`, and `credentials_file` variables), and create a new email credentials file (instructions for creating the credentials file are also in the `1 - user inputs` part of the script).

-   The process assumes that you have an account on the data.ca.gov portal (with rights to edit datasets managed by the [California State Water Resources Control Board](https://data.ca.gov/organization/california-state-water-resources-control-board) organizational account), and that you have the necessary credentials saved as Environment Variables on your computer (in Windows, search for "edit environment variables for your account"), which are accessed in the `user inputs` part of the script. The variables are:

    -   `portal_key`: API key for your personal data.ca.gov account (available on data.ca.gov by going to your user profile)

-   The process (optionally) saves data files to a separate directory (i.e., not necessarily the one in which this project is stored). This separate directory is defined by the `file_save_location` variable, and needs to be edited to run the script on a different computer. (As a side note, it's set up this way because, for my own use, I have the project saved to OneDrive, but I don't want to frequently save a lot of large files to a cloud location like OneDrive, so instead save them to the local C drive.)
