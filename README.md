# Information and Instructions - CA Open Data Portal Updates & Reports

The sub-folders in this repository contain scripts and process used to update some of the datasets on the [California Open Data Portal](https://data.ca.gov/) that are associated with the [California State Water Resources Control Board](https://data.ca.gov/organization/california-state-water-resources-control-board) organizational account. See the `README.md` file in each sub-folder for more information about each process.

In addition, the `_Data-Portal-Report` sub-folder contains a process to create an automated report about the Water Board's datasets and data resources on the portal. If also creates a dashboard that displays information about their status, which is available at: <https://cawaterdatadive.shinyapps.io/Data-Portal-Report/>

To automatically run these processes on a set schedule on a Windows computer, you can create a task in "Task Scheduler" that runs any of the files in the `_Call-Scripts` sub-folder of this repository. However, note that changes to the scripts that they call will likely be required before the first time they are run by a new user (or on a new computer). See the `README.md` file in each sub-folder for more information about any changes required before running the process.

Also, note that some of the scripts / processes listed here are no longer in use, as stated in the respective README.md files; they are provided here for reference only.
