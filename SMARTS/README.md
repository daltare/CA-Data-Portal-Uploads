# SMARTS Open Data Portal Updates

This process updates the data resources on the CA open data portal that are contained in the [Stormwater - Regulatory (including Enforcement Actions) Information and Water Quality Results](https://data.ca.gov/dataset/stormwater-regulatory-including-enforcement-actions-information-and-water-quality-results) dataset.

## Package Management - {renv}

This project uses [`renv`](https://rstudio.github.io/renv/articles/renv.html) for package management. When opening this project for the first time (ideally as an RStudio project, via the `SMARTS_Data_Download_Automation.Rproj` file), run `renv::restore()` to install all package dependencies (`renv` should automatically install itself and prompt you to do this).

In addition:

-   Use [`renv::status()`](https://rstudio.github.io/renv/reference/status.html) to check the status and fix any issues that arise (using the commands below).
-   Use [`renv::install()`](https://rstudio.github.io/renv/reference/install.html) to add packages, [`renv::update()`](https://rstudio.github.io/renv/reference/update.html) to update package versions, and [`renv::snapshot()`](https://rstudio.github.io/renv/reference/snapshot.html) after packages are added or updated (which will record the packages and their sources in the lockfile).
-   Use [`renv::restore()`](https://rstudio.github.io/renv/reference/restore.html) to get the specific package versions recorded in the lockfile.
-   The `renv` documentation notes that if you're making major changes to a project that you haven't worked on for a while, it's generally a good idea to start with an [`renv::update()`](https://rstudio.github.io/renv/reference/update.html) before making any changes to the code.

If you run into problems using `renv` and need to stop using it for this project, you can call [`renv::deactivate()`](https://rstudio.github.io/renv/reference/activate.html), as described [here](https://rstudio.github.io/renv/articles/renv.html#uninstalling-renv).

For more information, see [Introduction to renv](https://rstudio.github.io/renv/articles/renv.html).

## Instructions

The only required step is to run the `SMARTS_data_portal_automation.R` script (i.e., run `source('SMARTS_data_portal_automation.R')` or open the file in RStudio and click the `Source` button). This should handle all parts of the update process - some parts of the process will call other scripts, including `start_selenium.R`.

**NOTE: To just run the process which uploads data to the CA Data Portal (after the data has been downloaded from SMARTS and processed), run the `SMARTS_upload_to_portal_helper.R` script.**

To automatically run the process on a set schedule on a Windows computer, you can create a task in "Task Scheduler" that runs the `Call_SMARTS.bat` file (which is in the `_Call-Scripts` directory at the top level of this repository) on a specified day and time.

If the process fails at any point, it is set up to send an automated email alerting you that it has failed (and an attempt at telling you why it failed).

There are a few additional things to be aware of, which will likely require some set-up work before the first time the update process is run by a new user (or on a new computer):

-   To get an automated email with an alert when the process fails, you'll need to modify some variables in the `1 - user input` part of the `1_ceden_automate.R` script (including the `email_from`, `email_to`, and `credentials_file` variables), and create a new email credentials file (instructions for creating the credentials file are also in the `1 - user input` part of the script). You also need to setup the [`gmailr`](https://github.com/r-lib/gmailr) package to work with a personal gmail account, which can be a bit tricky - be sure to go over the [Setup and auth](https://github.com/r-lib/gmailr#setup-and-auth) instructions.

    -   NOTE: when you're on the Waterboard's VPN, there may be security settings that could cause the email notification process to fail. Between changes in the Waterboards VPN security policies/settings and changes in the packages and tools used to send the email notification, it's difficult to keep this process functioning, and it's not guaranteed to keep working as-is over time.

-   The process assumes that you have an account on the data.ca.gov portal (with rights to edit datasets managed by the [California State Water Resources Control Board](https://data.ca.gov/organization/california-state-water-resources-control-board) organizational account), and that you have the necessary credentials saved as Environment Variables on your computer (in Windows, search for "edit environment variables for your account"), which are accessed in the `1 - user input` part of the script. The variables are:

    -   `data_portal_key`: API key for your personal data.ca.gov account (available on data.ca.gov by going to your user profile)

-   The process (optionally) saves data files to a separate directory (i.e., not necessarily the one in which this project is stored). This separate directory is defined by the `download_dir` variable, and needs to be edited to run the script on a different computer. (As a side note, it's set up this way because, for my own use, I have the project saved to OneDrive, but I don't want to frequently save a lot of large files to a cloud location like OneDrive, so instead save them to the local C drive.)

If you ever need to update the data dictionary for any resource, you can use either the `data_dictionary_API_upload.R` or `data_dictionary_API_upload.py` script in the `ckan-data-dictionary-API-tool` folder to automate the process. In these scripts, you'll need to update the `dictionary_file` and `resources_to_update` variables to refer to the correct data dictionary information and resource ID for the resource(s) you're updating.
