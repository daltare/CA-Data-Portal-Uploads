library(dplyr)
library(ckanr)
library(readr)
library(writexl)

# set the ckanr defaults
    # get the data portal API key saved in the local environment (it's available on data.ca.gov by going to your user profile)
        portal_key <- Sys.getenv('data_portal_key')
    # set defaults
        ckanr_setup(url = 'https://data.ca.gov/', key = portal_key)

# get a list of all waterboard datasets (packages)
    # get the organization ID
        organization_list()
        organization_info <- organization_show(id = 'a652035f-505c-4c24-8464-fed3623acfcd', as = 'table')#, include_datasets = TRUE, rows = 100)
    # get the datasets using the organization ID
        waterboard_datasets <- package_search(q = 'owner_org:a652035f-505c-4c24-8464-fed3623acfcd', rows = 99999)
    # get all of the waterboard datasets and their IDs
        df_waterboard_datasets <- tibble()
        for (i in seq(length(waterboard_datasets$results))) {
            df_waterboard_datasets <- rbind(df_waterboard_datasets, 
                                    tibble('id' = waterboard_datasets$results[[i]]$id,
                                           'title' = waterboard_datasets$results[[i]]$title,
                                           'name' = waterboard_datasets$results[[i]]$name))
        }        

        
# get list of all waterboard resources
    df_waterboard_resources <- tibble()
    for (j in seq(nrow(df_waterboard_datasets))) {
        temp_resource <- package_show(id = df_waterboard_datasets$id[j])
            for (resource_num in seq(length(temp_resource$resources))) {
                df_waterboard_resources <- rbind(df_waterboard_resources,
                                                 tibble('dataset_title' = temp_resource$title,
                                                        'dataset_name' = temp_resource$name,
                                                        'dataset_id' = temp_resource$id,
                                                        'resource_name' = temp_resource$resources[[resource_num]]$name,
                                                        'resource_id' = temp_resource$resources[[resource_num]]$id,
                                                        'resource_url' = temp_resource$resources[[resource_num]]$url,
                                                        'resource_type' = temp_resource$resources[[resource_num]]$format,
                                                        'resource_last_update' = if (is.null(temp_resource$resources[[resource_num]]$last_modified)) {
                                                            NA} else {temp_resource$resources[[resource_num]]$last_modified}
                                                 ))
            }
    }
    
# reorder columns
    df_waterboard_resources <- df_waterboard_resources %>% 
        select(resource_name, resource_type, resource_last_update, dataset_title, resource_id, dataset_id, resource_url)
    
# write to csv
    write_csv(x = df_waterboard_resources, 
              path = paste0('CKAN-Data-Portal-Report_' , Sys.Date(), '.csv'))
    write_xlsx(x = list('CKAN-Data-Portal-Report' = df_waterboard_resources), 
               path = paste0('CKAN-Data-Portal-Report_' , Sys.Date(), '.xlsx'))
    