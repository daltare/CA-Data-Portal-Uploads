# Instructions - Surface Water Open Data Portal Updates

These scripts update the following data resources on the CA Open Data Portal:

- Reg_Meas_AnimalWaste.R: https://data.ca.gov/dataset/surface-water-water-quality-regulated-facility-information/resource/c16335af-f2dc-41e6-a429-f19edba5b957
- Reg_Meas_WastewaterFacilities-PermitsOrders.R: https://data.ca.gov/dataset/surface-water-water-quality-regulated-facility-information/resource/2446e10e-8682-4d7a-952e-07ffe20d4950
- Wastewater-Enforcement-Actions.R: https://data.ca.gov/dataset/surface-water-water-quality-regulatory-information/resource/64f25cad-2e10-4a66-8368-79293f56c2f1

The only required step is to run the R script associated with the given resource (e.g., run `source('Reg_Meas_AnimalWaste.R')` or open the file in RStudio and click the `Source` button). This should handle all parts of the update process.

To automatically run any of these update process on a set schedule on a Windows computer, you can create a task in "Task Scheduler" that runs the relevant .bat file (e.g., `Call_SurfaceWater_AnimalWaste.bat`) on a specified day and time. The .bat files are in the `_Call-Scripts` directory at the top level of this repository.

If the processes fail at any point, they are set up to send an automated email alerting you that the process has failed (and an attempt at telling you why it failed).

There are a few additional things to be aware of, which will likely require some set-up work before the first time the update process is run by a new user (or on a new computer):

-   To get an automated email with an alert when the process fails, you'll need to modify some variables in the `user inputs` part of the relevant script (including the `email_from`, `email_to`, and `credentials_file` variables), and create a new email credentials file (instructions for creating the credentials file are also in the `user inputs` part of the script).

-   The process assumes that you have an account on the data.ca.gov portal (with rights to edit datasets managed by the [California State Water Resources Control Board](https://data.ca.gov/organization/california-state-water-resources-control-board) organizational account), and that you have the necessary credentials saved as Environment Variables on your computer (in Windows, search for "edit environment variables for your account"), which are accessed in the `user inputs` part of the script. The variables are:

    -   `portal_key`: API key for your personal data.ca.gov account (available on data.ca.gov by going to your user profile)

-   The process (optionally) saves data files to a separate directory (i.e., not necessarily the one in which this project is stored). This separate directory is defined by the `file_save_location` variable, and needs to be edited to run the script on a different computer. (As a side note, it's set up this way because, for my own use, I have the project saved to OneDrive, but I don't want to frequently save a lot of large files to a cloud location like OneDrive, so instead save them to the local C drive.)
