## DA - this shows how to call the python chunked upload process as part of an R script

library(reticulate)

## install dependent python packages
# shell('cd portal-upload-ckan-chunked_eSMR') ### if needed, change to directory where requirements.txt file is located
shell('pip install -r requirements.txt')
# shell('cd ..') ### if needed, change back to original directory

## get function
source_python('main.py')