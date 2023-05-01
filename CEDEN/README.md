# Instructions - CEDEN Open Data Portal Updates

The only required step is to run the `1_ceden_automate.R` script (i.e., run `source('1_ceden_automate.R')` or open the file in RStudio and click the `Source` button). This should handle all parts of the update process - some parts of the process will call other scripts, including `start_selenium.R`, `1-1_ceden-zip-file-upload.R`, `1-2_ceden-parquet-conversion`, and `1-2_ceden-parquet-conversion`.

If the process fails at any point, it is set up to send an automated email alerting you that it has failed (and an attempt at telling you why it failed). If that happens, you may be able to diagnose / fix the problem and run the remaining parts of the `1_ceden_automate.R` script (without having to re-run the entire process).

There are a few additional things to be aware of, which will likely require some set-up work before the first time the update process is run by a new user (or on a new computer):

-   To get an automated email with an alert when the process fails, you'll need to modify some variables in the `1 - user input` part of the `1_ceden_automate.R` script (including the `email_from`, `email_to`, and `credentials_file` variables), and create a new email credentials file (instructions for creating the credentials file are also in the `1 - user input` part of the script).

-   The `1_ceden_automate.R` script assumes that you have an account on the data.ca.gov portal (with rights to edit datasets managed by the [California State Water Resources Control Board](https://data.ca.gov/organization/california-state-water-resources-control-board) organizational account), and that you have the necessary credentials saved as Environment Variables on your computer (in Windows, search for "edit environment variables for your account"), which are accessed in the `1 - user input` part of the script. The variables are:

    -   `portal_username`: username for your personal data.ca.gov account

    -   `portal_password`: password for your personal data.ca.gov account

    -   `data_portal_key`: API key for your personal data.ca.gov account (available on data.ca.gov by going to your user profile)

-   The `1_ceden_automate.R` script also assumes that you have access to the CEDEN data warehouse, and that you have the necessary credentials saved as Environment Variables on your computer (in Windows, search for "edit environment variables for your account"), which are accessed in the `1 - user input` part of the script. The variables are:

    -   `SERVER1`: CEDEN data warehouse name

    -   `UID`: CEDEN data warehouse user ID

    -   `PWD`: CEDEN data warehouse password

-   The process (optionally) saves data files to a separate directory (i.e., not necessarily the one in which this project is stored). This separate directory is defined by the `data_files_path` variable, and needs to be edited to run the script on a different computer. (As a side note, it's set up this way because, for my own use, I have the project saved to OneDrive, but I don't want to frequently save a lot of large files to a cloud location like OneDrive, so instead save them to the local C drive.)

Finally, over time it will be necessary to create new resources within each dataset on the data.ca.gov portal to hold data for additional years. The process to do this is:

1.  Create a new (empty) resource on data.ca.gov for the new year, and enter the resource name and description.
2.  Get the Resource ID from the URL of the newly created resource (the ID is the alpha numeric string at the end of the URL).
3.  Add the year and Resource ID as a new item in the relevant part of the list defined by the `upload_files_list` variable in the `1_ceden_automate.R` script (in the `1 - user input` section of the script).
4.  If you haven't yet run the whole update process (i.e., running the `1_ceden_automate.R` script), then run it as usual. Otherwise, if you just need to add the file with the data for the new year, manually upload the file to the new resource on data.ca.gov (but make sure you've completed step #3 above so that resource continues to be updated in the future).
5.  After the new file is uploaded, make sure the data format is correctly detected as CSV (manually set it to CSV if needed). Then, make sure the data is loaded into the Data Store, and the "Data Table" view of the resource is available (it may take a little while for all of this to get updated on the portal).
6.  One the data is loaded into the Data Store, you can update the data dictionary (this will add definitions of all variables, and will also set the data type for each variable). To automate this process, go to the `data_dictionaries\data_dictionary_conversion` directory in the project, then select the folder for the relevant data type and open the R script (i.e., `ceden_[data type]_data-dictionary-tool_yearly.R`). In the script, add the year and resource ID as a new item in the list defined by the `data_resource_id_list` variable (keep all other year/ID combinations commented out, unless you need to edit the data dictionary for any/all other years), then run the script.
