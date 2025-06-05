# Use the CKAN `datastore_create` API call to update the data dictionary 
# of an existing resource on the data.ca.gov portal. Requires that the data 
# dictionary information is saved in an existing Excel file. For more 
# information about how the information in the data dictionary file should be 
# structured, see the documentation for the `upload_ckan_data_dictionary` 
# function.
# 
# (Note: this process does not impact the data in that resource. For more 
# information, see: <https://stackoverflow.com/a/66698935>.)



# load packages -----------------------------------------------------------
import os
import polars as pl
import janitor.polars
import requests
# import json



# main --------------------------------------------------------------------
def main():
    # NOTE: to run, update the `data_dictionary_file` and `resources_to_update`
    # variables, and make sure the `portal_key` variable is correctly retrieving 
    # your personal data portal API key from your user environment
    
    # setup ----
    
    ## enter name of data dictionary file to use ----
    ## (see the documentation for the `upload_ckan_data_dictionary` function for specifications on how this file should be structured)
    data_dictionary_file = "eSMR_Data_Dictionary_Template.xlsx" 

    ## list resources to update ----
    ## dictionary values are the resource IDs - this is the alphanumeric part at the end of a resource's URL
    ## dictionary keys can be anything you want to use to label a resource (the keys aren't actually used for the API call; they're' just used to keep track of the API responses) 
    resources_to_update = {
        '2025': '176a58bf-6f5d-4e3f-9ed9-592a509870eb', 
        '2024': '7adb8aea-62fb-412f-9e67-d13b0729222f',
        '2023': '65eb7023-86b6-4960-b714-5f6574d43556',
        '2022': '8c6296f7-e226-42b7-9605-235cd33cdee2',
        '2021': '28d3a164-7cec-4baf-9b11-7a9322544cd6',
        '2020': '4fa56f3f-7dca-4dbd-bec4-fe53d5823905',
        '2019': '2eaa2d55-9024-431e-b902-9676db949174',
        '2018': 'bb3b3d85-44eb-4813-bbf9-ea3a0e623bb7',
        '2017': '44d1f39c-f21b-4060-8225-c175eaea129d',
        '2016': 'aacfe728-f063-452c-9dca-63482cc994ad',
        '2015': '81c399d4-f661-4808-8e6b-8e543281f1c9',
        '2014': 'c0f64b3f-d921-4eb9-aa95-af1827e5033e',
        '2013': '8fefc243-9131-457f-b180-144654c1f481',
        '2012': '67fe1c01-1c1c-416a-92e1-ee8437db615a',
        '2011': 'c495ca93-6dbe-4b23-9d17-797127c28914',
        '2010': '4eb833b3-f8e9-42e0-800e-2b1fe1e25b9c',
        '2009': '3607ae5c-d479-4520-a2d6-3112cf92f32f',
        '2008': 'c0e3c8be-1494-4833-b56d-f87707c9492c',
        '2007': '7b99f591-23ac-4345-b645-9adfaf5873f9',
        '2006': '763e2c90-7b7d-412e-bbb5-1f5327a5f84e'
    }

    ## retrieve data portal API key ----
    ## (available on data.ca.gov by going to your user profile)
    ## (key should be saved in the local environment)
    portal_key = os.getenv("data_portal_key") 
    
    
    # execute API call -----
    ## create empty dict to store API responses
    api_responses = {}
    
    ## upload the data dictionaries -----
    for resource, id in resources_to_update.items():
        api_response = upload_ckan_data_dictionary(resource_id = id, # ID of the resource to update
                                                   data_dictionary_file = data_dictionary_file, # name of file containing the data dictionary info
                                                   portal_key = portal_key) # get data portal API key (saved in the local environment) - available on data.ca.gov by going to your user profile
        
        # save the response status code
        api_responses[resource] = api_response.status_code
        
        # Print response status and content
        # print("Response Status Code:", api_response.status_code)
        # print("Response Body:", api_response.text)
        
    ## print API response status codes (should be "200" if successful)
    print(api_responses)



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
            - Label: The common English title for the data contained in this column.            
            - Type: One of the data types available on the portal - either 'text', 'numeric', or 'timestamp' (for the data.ca.gov portal, as of 2025-02)
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
    Transforms a data dictionary that's saved in a spreadsheet file into the format required for use in the CKAN datastore API's 'datastore_create' action.
    
    Args:
        data_dictionary_file: The filename of the workbook that contains the data dictionary information. The data dictionary should be in the first worksheet of the workbook, and the dictionary information should be in fields named: 'Column', 'Type', 'Label', and 'Description'. These fields should contain the following information:
            - Column: The name of the field as it's written in the source data table
            - Label: The common English title for the data contained in this column.
            - Type: One of the data types available on the portal - either 'text', 'numeric', or 'timestamp' (for the data.ca.gov portal, as of 2025-02)
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
