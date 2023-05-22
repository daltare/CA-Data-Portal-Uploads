# Instructions - Data Portal Report

These scripts automate the process of creating a report about the datasets and data resources associated with the [California State Water Resources Control Board](https://data.ca.gov/organization/california-state-water-resources-control-board) organizational account on the California Open Data Portal, and create a Shiny app that displays some of the results, at: <https://cawaterdatadive.shinyapps.io/Data-Portal-Report/>

The report, in the form of an Excel workbook containing metadata about all of the associated resources / datasets, is saved to the Water Board's SharePoint and Teams sites, at:

-   SharePoint: `OIMA` -\> `Data Integration & Analysis` -\> `CalEPA Open Data` -\> `Data-Portal-Report` -\> `DataPortalReport.xlsx` ([SharePoint Link](https://cawaterboards.sharepoint.com/sites/OIMA/DIA/Documents/CalEPA%20Open%20Data/Data-Portal-Report/DataPortalReport.xlsx?d=w29363af660234757b3efd8fbaa60b0cb))

-   Teams: `OIMA Data Team` -\> `Open Data` -\> `Files` -\> `Data-Portal-Report` -\> `DataPortalReport.xlsx` ([Teams Link](https://cawaterboards.sharepoint.com/:x:/r/sites/oimadatateam2/Shared%20Documents/Open%20Data/Data-Portal-Report/DataPortalReport.xlsx?d=w0b5b1728df9c4cd29f9ab007cbfb4fc9&csf=1&web=1&e=JrWPor))

To automatically run this report generation process on a set schedule on a Windows computer, you can create a task in "Task Scheduler" that runs the `Call_Portal_Report.bat` file on a specified day and time (the `Call_Portal_Report.bat` file is in the `_Call-Scripts` directory at the top level of this repository).

If the processes fail at any point, it is set up to send an automated email alerting you that the process has failed (and an attempt at telling you why it failed).

There are a few additional things to be aware of, which will likely require some set-up work before the first time the report generation process is run by a new user (or on a new computer):

-   To get an automated email with an alert when the process fails, you'll need to modify some variables in the `user inputs` part of the `2_save-portal-metadata.R` script (including the `email_from`, `email_to`, and `credentials_file` variables), and create a new email credentials file (instructions for creating the credentials file are also in the `1 - user inputs` part of the script).

-   The process saves the report to separate directories on the Water Board's SharePoint and Teams sites. The paths to these directories are defined by the `paths_output` variable in the `user inputs` part of the `2_save-portal-metadata.R` script. In order to save the data to these Sharepoint and/or Teams locations, you must:

    -   have access to the relevant WB / OIMA sharepoint site and Teams channel, and

    -   sync the folders on the WB / OIMA sharepoint site and Teams channel to your local computer, and update the `paths_output` variable accordingly (at a minimum you'll need to enter the username for your computer).