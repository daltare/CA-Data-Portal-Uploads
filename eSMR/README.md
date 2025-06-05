# eSMR Open Data Portal Updates

This process updates the data resources on the CA open data portal that are contained in the [Water Quality - Effluent - Electronic Self-Monitoring Report (eSMR) Data](https://data.ca.gov/dataset/water-quality-effluent-electronic-self-monitoring-report-esmr-data) dataset.

## Package Management - {renv}

This project uses [`renv`](https://rstudio.github.io/renv/articles/renv.html) for package management. When opening this project for the first time (ideally as an RStudio project, via the `eSMR.Rproj` file), run `renv::restore()` to install all package dependencies (`renv` should automatically install itself and prompt you to do this).

In addition:

-   Use [`renv::status()`](https://rstudio.github.io/renv/reference/status.html) to check the status and fix any issues that arise (using the commands below).
-   Use [`renv::install()`](https://rstudio.github.io/renv/reference/install.html) to add packages, [`renv::update()`](https://rstudio.github.io/renv/reference/update.html) to update package versions, and [`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html) after packages are added or updated (which will record the packages and their sources in the lockfile).
-   Use [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html) to get the specific package versions recorded in the lockfile.
-   The `renv` documentation notes that if you're making major changes to a project that you haven't worked on for a while, it's generally a good idea to start with an [`renv::update()`](https://rstudio.github.io/renv/reference/update.html) before making any changes to the code.

If you run into problems using `renv` and need to stop using it for this project, you can call [`renv::deactivate()`](https://rstudio.github.io/renv/reference/activate.html), as described [here](https://rstudio.github.io/renv/articles/renv.html#uninstalling-renv).

For more information, see [Introduction to renv](https://rstudio.github.io/renv/articles/renv.html).

## Instructions

In general, the only required step to execute the process is to run the `1_eSMR_data-portal-automate.R` script (i.e., run `source('1_eSMR_data-portal-automate.R')` or open the file in RStudio and click the `Source` button). This should handle all parts of the update process - some parts of the process will call other scripts, including `start_selenium.R` and `1-1_eSMR_zip-file-uploads.R`. However, see below for some additional steps that may be needed when setting up this process for the first time on a new computer. 

If the process fails at any point, it is set up to send an automated email alerting you that it has failed (and an attempt at telling you why it failed). If that happens, you may be able to diagnose / fix the problem and run the remaining parts of the `1_eSMR_data-portal-automate.R` script (without having to re-run the entire process).

The process contains an option to only upload CSV data from recent years to the portal (rather than uploading the CSV files for all years). This was designed to speed the process and make it more feasible to run the updates more frequently, on the assumption that less recent data will change infrequently (if at all). The option to set which years of CSV files to upload is controlled by the `years_write` variable in the `1_eSMR_data-portal-automate.R` script. Note that this only applies to the data written as CSV files for individual years - bulk zip files containing all years' data will always include the most recent data across all years.

There are a few additional things to be aware of, which will likely require some set-up work before the first time the update process is run by a new user (or on a new computer):

-   To get an automated email with an alert when the process fails, you'll need to modify some variables in the `1 - user input` part of the `eSMR_data-portal-upload.R` script (including the `email_from`, `email_to`, and `credentials_file` variables), and create a new email credentials file (instructions for creating the credentials file are also in the `1 - user input` part of the script). You also need to setup the [`gmailr`](https://github.com/r-lib/gmailr) package to work with a personal gmail account, which can be a bit tricky - be sure to go over the [Setup and auth](https://github.com/r-lib/gmailr#setup-and-auth) instructions.

    -   NOTE: when you're on the Waterboard's VPN, there may be security settings that could cause the email notification process to fail. Between changes in the Waterboards VPN security policies/settings and changes in the packages and tools used to send the email notification, it's difficult to keep this process functioning, and it's not guaranteed to keep working as-is over time.

-   The `1_eSMR_data-portal-automate.R` script assumes that you have an account on the data.ca.gov portal (with rights to edit datasets managed by the [California State Water Resources Control Board](https://data.ca.gov/organization/california-state-water-resources-control-board) organizational account), and that you have the necessary credentials saved as Environment Variables on your computer (in Windows, search for "edit environment variables for your account"), which are accessed in the `1 - user input` part of the script. The variables are:

    -   `portal_username`: username for your personal data.ca.gov account

    -   `portal_password`: password for your personal data.ca.gov account

    -   `data_portal_key`: API key for your personal data.ca.gov account (available on data.ca.gov by going to your user profile)

-   The `1_eSMR_data-portal-automate.R` script also assumes that you have access to the CIWQS flat files on the Water Board's intranet. The path to those data sources are defined by the `esmr_url` and `smr_url` variables in the `1 - user input` part of the script.

-   The process (optionally) saves data files to a separate directory (i.e., not necessarily the one in which this project is stored). This separate directory is defined by the `download_dir` variable (in the `1 - user input` part of the `1_eSMR_data-portal-automate.R` script), and needs to be edited to run the script on a different computer. (As a side note, it's set up this way because, for my own use, I have the project saved to OneDrive, but I don't want to frequently save a lot of large files to a cloud location like OneDrive, so instead save them to the local C drive.)

Finally, over time it will be necessary to create new resources on the data.ca.gov portal to hold data for additional years. The process to do this is:

1.  Create a new (empty) resource on data.ca.gov for the new year, and enter the resource name and description.
2.  Get the Resource ID from the URL of the newly created resource (the ID is the alpha numeric string at the end of the URL).
3.  Add the year and Resource ID as a new item in the list defined by the `data_resource_id_list` variable in the `1_eSMR_data-portal-automate.R` script (in the `1 - user input` section of the script).
4.  If you haven't yet run the whole update process (i.e., running the `1_eSMR_data-portal-automate.R` script), then run it as usual. Otherwise, if you just need to add the file with the data for the new year, manually upload the file to the new resource on data.ca.gov (but make sure you've completed step #3 above so that resource continues to be updated in the future).
5.  After the new file is uploaded, make sure the data format is correctly detected as CSV (manually set it to CSV if needed). Then, make sure the data is loaded into the Data Store, and the "Data Table" view of the resource is available (it may take a little while for all of this to get updated on the portal).
6.  Once the data is loaded into the Data Store, you can update the data dictionary (this will add definitions of all variables, and will also set the data type for each variable). To automate this process, go to the `data_dictionaries\data_dictionary_conversion` directory in the project, then select the folder for the relevant data type and open the R script (i.e., `data_dictionary_API_upload.R`). In the script, add the year and resource ID as a new item in the list defined by the `resources_to_update` variable (comment out all other year/ID combinations, unless you need to edit the data dictionary for any/all other years), then run the script. Alternatively, you can use a python version of this script, which is called `data_dictionary_API_upload.py` (also in the `data_dictionaries\data_dictionary_conversion` directory).
