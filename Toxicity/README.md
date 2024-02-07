# Instructions - CEDEN Toxicity Summary / Replicate Open Data Portal Updates

These scripts update the CEDEN Toxicity [Summary](https://data.ca.gov/dataset/surface-water-toxicity-results/resource/674474eb-e093-42de-aef3-da84fd2ff2d8) and [Replicate](https://data.ca.gov/dataset/surface-water-toxicity-results/resource/6fd7b8d7-f8dd-454f-98bb-07e8cc710db8) data resources on the CA open data portal.

The only required step is to run the `Toxicity-Summary-Replicate-Data-Pull.R` script (e.g., run `source('Toxicity-Summary-Replicate-Data-Pull.R')` or open the file in RStudio and click the `Source` button). This should handle all parts of the update process.

------------------------------------------------------------------------

***NOTE:** This process pulls Toxicity data from the CEDEN datamart. However, unlike the other CEDEN datasets published to the open data portal, this process pulls data from the `WebSvc_Tox` table in the datamart (the other CEDEN datasets pull from the `[datatype]Dmart_MV` tables - e.g., `ToxDmart_MV`), because the `WebSvc_Tox` table contains fields needed for this process that are not available in the `ToxDmart_MV` table.*

------------------------------------------------------------------------

To automatically run this update process on a set schedule on a Windows computer, you can create a task in "Task Scheduler" that runs the `Call_Toxicity_Summary_Replicate.bat` file on a specified day and time (the `Call_Toxicity_Summary_Replicate.bat` file is in the `_Call-Scripts` directory at the top level of this repository).

If the processes fail at any point, they are set up to send an automated email alerting you that the process has failed (and an attempt at telling you why it failed).

There are a few additional things to be aware of, which will likely require some set-up work before the first time the update process is run by a new user (or on a new computer):

-   To get an automated email with an alert when the process fails, you'll need to modify some variables in the `user inputs` part of the script (including the `email_from`, `email_to`, and `credentials_file` variables), and create a new email credentials file (instructions for creating the credentials file are also in the `user inputs` part of the script). You also need to setup the [`gmailr`](https://github.com/r-lib/gmailr) package to work with a personal gmail account, which can be a bit tricky - be sure to go over the [Setup and auth](https://github.com/r-lib/gmailr#setup-and-auth) instructions.

    -   NOTE: when you're on the Waterboard's VPN, there may be security settings that could cause the email notification process to fail. Between changes in the Waterboards VPN security policies/settings and changes in the packages and tools used to send the email notification, it's difficult to keep this process functioning, and it's not guaranteed to keep working as-is over time.

-   The process assumes that you have an account on the data.ca.gov portal (with rights to edit datasets managed by the [California State Water Resources Control Board](https://data.ca.gov/organization/california-state-water-resources-control-board) organizational account), and that you have the necessary credentials saved as Environment Variables on your computer (in Windows, search for "edit environment variables for your account"), which are accessed in the `user inputs` part of the script. The variables are:

    -   `portal_key`: API key for your personal data.ca.gov account (available on data.ca.gov by going to your user profile)

-   The process also assumes that you have access to the CEDEN data warehouse, and that you have the necessary credentials saved as Environment Variables on your computer (in Windows, search for "edit environment variables for your account"), which are accessed in the `user inputs` part of the script. The variables are:

    -   `ceden_server`: CEDEN data warehouse name

    -   `ceden_user_id`: CEDEN data warehouse user ID

    -   `ceden_password`: CEDEN data warehouse password

-   The process (optionally) saves data files to a separate directory (i.e., not necessarily the one in which this project is stored). This separate directory is defined by the `file_save_location` variable, and needs to be edited to run the script on a different computer. (As a side note, it's set up this way because, for my own use, I have the project saved to OneDrive, but I don't want to frequently save a lot of large files to a cloud location like OneDrive, so instead save them to the local C drive.)
