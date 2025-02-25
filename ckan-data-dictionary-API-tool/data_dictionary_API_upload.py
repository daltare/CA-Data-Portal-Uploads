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
    data_dictionary_file = "CEDEN_Chemistry_Data_Dictionary.xlsx" 

    ## list resources to update ----
    ## dictionary values are the resource IDs - this is the alphanumeric part at the end of a resource's URL
    ## dictionary keys can be anything you want to use to label a resource (the keys aren't actually used for the API call; they're' just used to keep track of the API responses) 
    resources_to_update = {
        'year-2025': '97b8bb60-8e58-4c97-a07f-d51a48cd36d4',
        'year-2024': '9dcf551f-452d-4257-b857-30fbcc883a03',
        'year-2023': '6f9dd0e2-4e16-46c2-bed1-fa844d92df3c',
        'year-2022': '5d7175c8-dfc6-4c43-b78a-c5108a61c053',
        'year-2021': 'dde19a95-504b-48d7-8f3e-8af3d484009f',
        'year-2020': '2eba14fa-2678-4d54-ad8b-f60784c1b234',
        'year-2019': '6cf99106-f45f-4c17-80af-b91603f391d9',
        'year-2018': 'f638c764-89d5-4756-ac17-f6b20555d694',
        'year-2017': '68787549-8a78-4eea-b5b9-ef719e65a05c',
        'year-2016': '42b906a2-9e30-4e44-92c9-0f94561e47fe',
        'year-2015': '7d9384fa-70e1-4986-81d6-438ce5565be6',
        'year-2014': '7abfde16-61b6-425d-9c57-d6bd70700603',
        'year-2013': '341627e6-a483-4e9e-9a85-9f73b6ddbbba',
        'year-2012': 'f9dd0348-85d5-4945-aa62-c7c9ad4cf6fd',
        'year-2011': '4d01a693-2a22-466a-a60b-3d6f236326ff',
        'year-2010': '572bf4d2-e83d-490a-9aa5-c1d574e36ae0',
        'year-2009': '5b136831-8870-46f2-8f72-fe79c23d7118',
        'year-2008': 'c587a47f-ac28-4f77-b85e-837939276a28',
        'year-2007': '13e64899-df32-461c-bec1-a4e72fcbbcfa',
        'year-2006': 'a31a7864-06b9-4a81-92ba-d8912834ca1d',
        'year-2005': '9538cbfa-f8be-4445-97dc-b931579bb927',
        'year-2004': 'c962f46d-6a7b-4618-90ec-3c8522836f28',
        'year-2003': 'd3f59df4-2a8d-4b40-b90f-8147e73335d9',
        'year-2002': '00c4ca34-064f-4526-8276-57533a1a36d9',
        'year-2001': 'cec6768c-99d3-45bf-9e56-d62561e9939e',
        'year-2000': '99402c9c-5175-47ca-8fce-cb6c5ecc8be6',
        'prior_to_2000': '158c8ca1-b02f-4665-99d6-2c1c15b6de5a'
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