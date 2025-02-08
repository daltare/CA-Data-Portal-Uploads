# This uses the CKAN `datastore_create` API call to update the data dictionary 
# of an existing resouce on the data.ca.gov portal. This process does not impact 
# the data in that resource. For more information, see: 
# <https://stackoverflow.com/a/66698935>.
# 
# The process defined here assumes that the data dictionary information is saved 
# in an existing file (like an Excel workbook or CSV file - it's currently designed
# to accept an Excel file, and slight modifications will need to be made if using 
# it with a CSV). 



# setup --------------------------------------------------------------------
import os
import polars as pl
import json
import requests

## get data portal API key (saved in the local environment) ----
## (it's available on data.ca.gov by going to your user profile)
portal_key = os.getenv("data_portal_key")

## define ID of resource to update ----
resource_id = "fe359a58-d785-4d45-af72-5e8b0f5428ff" # 2024 CEDEN tissue data 

## define name of file with data dictionary info ----
dictionary_file = "CEDEN_Tissue_Data_Dictionary.xlsx"



# get and format dictionary data -------------------------------------------

## read dictionary data from file ----
df_data_dict = pl.read_excel(dictionary_file)

## select needed columns ----
df_data_dict = df_data_dict.select(["column", "type", "label", "description"])

## reformat to nested structure ----
df_data_dict_format = (
    df_data_dict
    .with_columns(
        type_override = pl.col("type"),
        notes = pl.col("description")
    )
    .with_columns(
        pl.struct(["label", "notes", "type_override"]).alias("info") # make nested structure
    )
    .select([
        pl.col("column").alias("id"), # rename "column" field to "id"
        pl.col("type"),
        pl.col("info")
    ])
)
# print(df_data_dict_format.head()) # check

## Convert to dictionary format ----
json_dictionary = df_data_dict_format.to_dicts()
# print(json.dumps(json_dictionary, indent=2)) # check



# make API request ---------------------------------------------------------

## Define API endpoint and headers ----
base_url = "https://data.ca.gov/api/3/action/datastore_create"

headers = {
    "Authorization": portal_key, 
    "Content-Type": "application/json"
}

## Create request body ----
request_body = {
    "resource_id": resource_id, 
    "force": "True",
    "fields": json_dictionary  
}

## Test the request ----
# print("Request Body for Dry Run:")
# print(json.dumps(request_body, indent=2))

# Execute the request ----
response = requests.post(base_url, 
                         headers=headers, 
                         json=request_body)

# # Print response status and content
print("Response Status Code:", response.status_code)
print("Response Body:", response.text)
