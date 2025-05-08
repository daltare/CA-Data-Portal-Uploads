# These functions use the CKAN `datastore_create` API call to update the data 
# dictionary of an existing resource on a CKAN portal. These functions assume 
# that the data dictionary information is saved in an existing Excel file.
#
# (Note that this process does not impact the data in that resource - for more 
# information, see:  <https://stackoverflow.com/a/66698935>.)



# function to get and format dictionary data ------------------------------
#' Title
#' Format Data Dictionary
#' 
#' @description
#' Transform a data dictionary that's saved in a spreadsheet file into the format required for use in the CKAN datastore API's 'datastore_create' action.
#'
#' @param data_dictionary_file The filename of the workbook that contains the data dictionary information. The data dictionary should be in the first worksheet of the workbook, and the dictionary information should be in fields named: 'Column', 'Type', 'Label', and 'Description'. These fields should contain the following information:
#' - Column: The name of the field as it's written in the source data table
#' - Label: The common English title for the data contained in this column.
#' - Type: One of the data types available on the portal - either 'text', 'numeric', or 'timestamp' (for the data.ca.gov portal, as of 2025-02)
#' - Description: Full description of what information is included for the field.
#'
#' @return The formatted data dictionary information, in JSON format.
#' 
#' @export
#'
#' @examples
#' data_dictionary_formatted <- format_data_dictionary(data_dictionary_file = "CEDEN_Chemistry_Data_Dictionary.xlsx")
format_data_dictionary <- function(data_dictionary_file) {
  
  ## read dictionary info ----
  df_dictionary <- readxl::read_excel(data_dictionary_file) |> 
    janitor::clean_names() |> 
    dplyr::select(dplyr::all_of(c('column', 'type', 'label', 'description'))) # just keep the relevant fields
  
  ## reformat to nested structure ----
  df_dictionary_format <- df_dictionary |> 
    dplyr::rowwise() |> 
    dplyr::mutate(info = tibble('label' = label,
                         'notes' = description,
                         'type_override' = type)) |> 
    dplyr::ungroup() |> 
    dplyr::select(id = column,
           type,
           info)
  
  ## convert to JSON ----
  json_dictionary <- df_dictionary_format |> 
    jsonlite::toJSON()
  
  return(json_dictionary)
}



# function to execute API request -----------------------------------------
#' Execute Data Dictionary API Upload
#' 
#' @description
#' Execute the API call to upload a formatted data dictionary to a CKAN data portal.
#' 
#'
#' @param data_dictionary_formatted The data dictionary information to be uploaded, in JSON format. Generated with the `format_data_dictionary` function.
#' @param resource_id The ID of the data resource the data dictionary will be loaded to (this is the alphanumeric code at the end of a resource's URL).
#' @param portal_key The user's API key for the data portal. This is available by going to the user's profile on the data portal. The portal key should be stored in an environment variable.
#' @param base_url The base of the URL used to execute the API call, including the URL of the data portal (e.g., 'data.ca.gov') and the 'datastore_create' API action (for more information, see <https://docs.ckan.org/en/2.9/maintaining/datastore.html#ckanext.datastore.logic.action.datastore_create>). Defaults to `https://data.ca.gov/api/3/action/datastore_create`.
#'
#' @return The result of the API request. 
#' 
#' @export
#'
#' @examples
#' api_response <- execute_data_dictionary_api_call(
#'  data_dictionary_formatted, # generate this with the format_data_dictionary function
#'  resource_id = "97b8bb60-8e58-4c97-a07f-d51a48cd36d4", 
#'  portal_key = Sys.getenv('data_portal_key')
#'  )
execute_data_dictionary_api_call <- function(data_dictionary_formatted, 
                                             resource_id, 
                                             portal_key,
                                             base_url = "https://data.ca.gov/api/3/action/datastore_create") {
  ## create base request ----
  req <- httr2::request(base_url)
  
  ## add headers ----
  req <- req |> 
    httr2::req_headers("Authorization" = portal_key,
                "Content-Type" = "application/json")
  
  ## create and add request body (with field info) ----
  request_body <- glue::glue('{{"resource_id": "{resource_id}", "force": "True", "fields": {data_dictionary_formatted} }}')
  
  req <- req |>
    httr2::req_body_raw(request_body)
  
  
  ## send API request ----
  resp <- req |> 
    httr2::req_perform() # execute
  
  ## return the response
  return(resp)
}



# function to format and upload the data dictionary info ------------------
#' Title
#' 
#' @description
#' Upload a data dictionary stored in a spreadsheet to a CKAN data portal. This function calls two helper functions, including 'format_data_dictionary' which transforms the data dictionary information into the format required for the API call, and 'execute_data_dictionary_api_call' which executes the API call and returns the response.
#'
#' @param resource_id The ID of the data resource the data dictionary will be loaded to (this is the alphanumeric code at the end of a resource's URL).
#' @param data_dictionary_file The filename of the workbook that contains the data dictionary information. The data dictionary should be in the first worksheet of the workbook, and the dictionary information should be in fields named: 'Column', 'Type', 'Label', and 'Description'. These fields should contain the following information:
#' - Column: The name of the field as it's written in the source data table
#' - Label: The common English title for the data contained in this column.
#' - Type: One of the data types available on the portal - either 'text', 'numeric', or 'timestamp' (for the data.ca.gov portal, as of 2025-02)
#' - Description: Full description of what information is included for the field.
#' @param portal_key The user's API key for the data portal. This is available by going to the user's profile on the data portal. The portal key should be stored in an environment variable.
#' @param base_url The base of the URL used to execute the API call, including the URL of the data portal (e.g., 'data.ca.gov') and the 'datastore_create' API action (for more information, see <https://docs.ckan.org/en/2.9/maintaining/datastore.html#ckanext.datastore.logic.action.datastore_create>). Defaults to `https://data.ca.gov/api/3/action/datastore_create`.
#'
#' @return The result of the API request. 
#' 
#' @export
#'
#' @examples
#' #' api_response <- upload_ckan_data_dictionary(
#'  resource_id = "97b8bb60-8e58-4c97-a07f-d51a48cd36d4", 
#'  data_dictionary_file = "CEDEN_Chemistry_Data_Dictionary.xlsx",
#'  portal_key = Sys.getenv('data_portal_key')
#'  )
upload_ckan_data_dictionary <- function(resource_id, 
                                        data_dictionary_file, 
                                        portal_key,
                                        base_url = "https://data.ca.gov/api/3/action/datastore_create") {
  
  ## format data dictionary for portal API upload
  data_dictionary_formatted <- format_data_dictionary(data_dictionary_file = data_dictionary_file)
  
  ## execute API call
  api_response <- execute_data_dictionary_api_call(data_dictionary_formatted = data_dictionary_formatted, 
                                                  resource_id = resource_id, 
                                                  portal_key = portal_key,
                                                  base_url = base_url)
  
  return(api_response)
}
