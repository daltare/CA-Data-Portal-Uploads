# This uses the CKAN `datastore_create` API call to update the data dictionary 
# of an existing resource on the data.ca.gov portal. This process does not impact 
# the data in that resource. For more information, see: 
# <https://stackoverflow.com/a/66698935>.
# 
# The process defined here assumes that the data dictionary information is saved 
# in an existing file (like an Excel workbook or CSV file - it's currently designed
# to accept an Excel file, and slight modifications will need to be made if using 
# it with a CSV). For more information about how the information in the data 
# dictionary file should be structured, see the documentation for the 
# `upload_ckan_data_dictionary` function.



# setup --------------------------------------------------------------------
import os
import polars as pl
import janitor.polars
import requests
# import json



# main function -----------------------------------------------------------
def main():
    ## upload the data dictionary
    api_response = upload_ckan_data_dictionary(resource_id = "fe359a58-d785-4d45-af72-5e8b0f5428ff", # 2024 CEDEN tissue data 
                                               data_dictionary_file = "CEDEN_Tissue_Data_Dictionary.xlsx", # name of file containing the data dictionary info
                                               portal_key = os.getenv("data_portal_key")) # get data portal API key (saved in the local environment) - available on data.ca.gov by going to your user profile

    # Print response status and content
    print("Response Status Code:", api_response.status_code)
    print("Response Body:", api_response.text)



# format and upload the data dictionary info ------------------------------
def upload_ckan_data_dictionary(resource_id: str, 
                                data_dictionary_file: str, 
                                portal_key: str,
                                base_url: str = "https://data.ca.gov/api/3/action/datastore_create"
                                ) -> requests.models.Response:
    
    """
    Upload a data dictionary stored in a spreadsheet to a CKAN data portal. This function calls two helper functions, including 'format_data_dictionary' which transforms the data dictionary information into the format required for the API call, and 'execute_data_dictionary_api_call' which executes the API call and returns the response.
    
    Args:
        resource_id: The ID of the data resource the data dictionary will be loaded to (this is the alphanumeric code at the end of a resource's URL). 
        
        data_dictionary_file: The filename of the workbook that contains the data dictionary information. The data dictionary should be in the first worksheet of the workbook, and the dictionary information should be in fields named: 'Column', 'Type', 'Label', and 'Description'. These fields should contain the following information:
            - Column: The name of the field as it's written in the source data table
            - Type: One of the data types available on the portal - either 'text', 'numeric', or 'timestamp' (for the data.ca.gov portal, as of 2025-02)
            - Label: The common English title for the data contained in this column.
            - Description: Full description of what information is included for the field.
            
        portal_key: The user's API key for the data portal. This is available by going to the user's profile on the data portal. The portal key should be stored in an environment variable.
        
        base_url: The base of the URL used to execute the API call, including the URL of the data portal (e.g., 'data.ca.gov') and the 'datastore_create' API action (for more information, see <https://docs.ckan.org/en/2.9/maintaining/datastore.html#ckanext.datastore.logic.action.datastore_create>).

    Returns:
        The result of the API request. The status code is accessible using `.status_code`, and the full text of the API response is available using `.response`.
    """
    
    # format data dictionary for portal API upload
    data_dictionary_formatted = format_data_dictionary(data_dictionary_file = data_dictionary_file)
    
    # execute API call
    api_response = execute_data_dictionary_api_call(data_dictionary_formatted = data_dictionary_formatted, 
                                                    resource_id = resource_id, 
                                                    portal_key = portal_key,
                                                    base_url = base_url)
    
    return api_response



# get and format dictionary data -------------------------------------------
def format_data_dictionary(data_dictionary_file: str) -> list[dict[str, str]]:
    
    """
    Transforms a data dictionary into the format required for use in the CKAN datastore API's 'datastore_create' action.
    
    Args:
        data_dictionary_file: The filename of the workbook that contains the data dictionary information. The data dictionary should be in the first worksheet of the workbook, and the dictionary information should be in fields named: 'Column', 'Type', 'Label', and 'Description'. These fields should contain the following information:
            - Column: The name of the field as it's written in the source data table
            - Type: One of the data types available on the portal - either 'text', 'numeric', or 'timestamp' (for the data.ca.gov portal, as of 2025-02)
            - Label: The common English title for the data contained in this column.
            - Description: Full description of what information is included for the field.

    Returns:
        The formatted data dictionary information, as a list of dictionaries.
    """
    
    ## read dictionary data from file ----
    df_data_dict = pl.read_excel(data_dictionary_file).clean_names()

    ## select needed columns ----
    df_data_dict = df_data_dict.select(["column", "type", "label", "description"])
    # print(df_data_dict.head()) # check

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
    
    return json_dictionary



# execute API request ---------------------------------------------------------
def execute_data_dictionary_api_call(data_dictionary_formatted: list[dict[str, str]],
                                     resource_id: str,
                                     portal_key: str,
                                     base_url: str = "https://data.ca.gov/api/3/action/datastore_create"
                                     ) -> requests.models.Response:
    
    """
    Execute the API call to upload a formatted data dictionary to a CKAN data portal.
    
    Args:
        data_dictionary_formatted: The data dictionary information to be uploaded, formatted as a list of dictionaries. Generated with the `format_data_dictionary` function.
        
        resource_id: The ID of the data resource the data dictionary will be loaded to (this is the alphanumeric code at the end of a resource's URL). 
            
        portal_key: The user's API key for the data portal. This is available by going to the user's profile on the data portal. The portal key should be stored in an environment variable.
        
        base_url: The base of the URL used to execute the API call, including the URL of the data portal (e.g., 'data.ca.gov') and the 'datastore_create' API action (for more information, see <https://docs.ckan.org/en/2.9/maintaining/datastore.html#ckanext.datastore.logic.action.datastore_create>).

    Returns:
        The result of the API request. The status code is accessible using `.status_code`, and the full text of the API response is available using `.response`.
    """
    
    ## Define headers ----
    headers = {
        "Authorization": portal_key, 
        "Content-Type": "application/json"
        }

    ## Create request body ----
    request_body = {
        "resource_id": resource_id, 
        "force": "True",
        "fields": data_dictionary_formatted
        }

    ## Test the request ----
    # print("Request Body for Dry Run:")
    # print(json.dumps(request_body, indent=2))

    # Execute the request ----
    response = requests.post(base_url, 
                            headers=headers, 
                            json=request_body)
    
    return response



# run main function ----------------------------------------------------------
if __name__ == "__main__":
    main()