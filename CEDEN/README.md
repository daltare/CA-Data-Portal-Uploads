# Instructions

The only required step is to run the `1_ceden_automate.R` script (i.e., run `source('1_ceden_automate.R')` or open the file in RStudio and click the `Source` button. This should handle all parts of the update process - some parts of the process will call other scripts, including `1-1_ceden-zip-file-upload.R`, `1-2_ceden-parquet-conversion`, and `1-2_ceden-parquet-conversion`.

Note that this script assumes that you have an account on the data.ca.gov portal (with rights to edit datasets managed by the [California State Water Resources Control Board](https://data.ca.gov/organization/california-state-water-resources-control-board) organizational account), and that you have the necessary credentials saved as Environment Variables on your computer (in Windows, search for "edit environment variables for your account") - see the `1 - user input` part of the script for the necessary credentials.

The script also saves raw data files to a separate directory, defined by the `data_files_path` variable (this is because, on my computer, I have the project saved to OneDrive; but, I don't want to save a lot of large files to OneDrive, so instead save them to the local C drive) - that needs to be edited to run the script on a different computer.
