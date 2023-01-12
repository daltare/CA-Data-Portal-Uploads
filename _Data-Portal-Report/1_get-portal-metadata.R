
# load packages -----------------------------------------------------------
library(ckanr)
library(tidyverse)
library(lubridate)
# library(writexl)
# library(here)




# setup -------------------------------------------------------------------
ckanr_setup(url = 'https://data.ca.gov/')


# dataset level metadata --------------------------------------------------
## download dataset metadata ----
df_datasets <- package_search(q = 'owner_org:a652035f-505c-4c24-8464-fed3623acfcd', 
                              rows = 99999, 
                              as = 'table')
df_datasets <- df_datasets$results

### format dataset metadata ----
df_datasets_format <- df_datasets %>% 
    filter(!private) %>% # show only public datasets
    select('dataset_name' = title,
           'dataset_last_update' = metadata_modified, # dates/times modified below to PST
           'dataset_created' =  metadata_created, # dates/times modified below to PST
           num_resources,
           'dataset_url' = name, # modified below to create full link
           'public_access_level' = accessLevel,
           rights,
           'program_contact_name' = contact_name, 
           'program_contact_email' = contact_email, 
           author, 
           # author_email,
           # maintainer, maintainer_email,
           'homepage_url' = landingPage,
           'frequency' = accrualPeriodicity, # modified below to translate codes into plain text
           'temporal_coverage' = temporal,
           granularity,
           'geographic_coverage_location' = geo_coverage,
           'data_standard' = conformsTo,
           language,
           'source_link' = url,
           'dataset_description' = notes,
           additional_information,
           related_resources,
           secondary_sources,
           citation,
           # group,
           dataset_id = 'id'
           ) %>% 
    mutate(dataset_created =  dataset_created %>% 
               ymd_hms() %>% 
               with_tz(tzone = 'America/Los_Angeles') %>% 
               # as.character() %>% 
               {.},
           dataset_last_update = dataset_last_update %>% 
               ymd_hms() %>% 
               with_tz(tzone = 'America/Los_Angeles') %>% 
               # as.character() %>% 
               {.}) %>%
    mutate(dataset_last_update = case_when(
        is.na(dataset_last_update) ~ min(dataset_created, na.rm = TRUE),
        TRUE ~ dataset_last_update)) %>% 
    mutate(dataset_last_update_within = case_when(
        dataset_last_update >= today() - 1 ~ '1 Day', # for last 24 hours: dataset_last_update >= now() - 60*60*24, 
        dataset_last_update >= today() - 7 ~ '2 Days to 1 Week',
        dataset_last_update >= add_with_rollback(today(), months(-1)) ~ '1 Week to 1 Month',
        dataset_last_update >= add_with_rollback(today(), months(-3)) ~ '1 to 3 Months',
        dataset_last_update >= add_with_rollback(today(), months(-6)) ~ '3 to 6 Months',
        dataset_last_update >= add_with_rollback(today(), months(-12)) ~ '6 Months to 1 Year',
        dataset_last_update < add_with_rollback(today(), months(-12)) ~ '> 1 Year')) %>%
    relocate(dataset_last_update_within, 
             .after = dataset_last_update) %>% 
    arrange(dataset_name) %>% 
    mutate(dataset_url = paste0('https://data.ca.gov/dataset/', dataset_url)) %>% 
    mutate(frequency = case_when(frequency == 'R/P1D' ~ 'Daily', 
                                 frequency == 'R/P1W' ~ 'Weekly',
                                 frequency == 'R/P1M' ~ 'Monthly',
                                 frequency == 'R/P2M' ~ 'Every Two Months',
                                 frequency == 'R/P3M' ~ 'Quarterly',
                                 frequency == 'R/P6M' ~ 'Semiannual',
                                 frequency == 'R/P1Y' ~ 'Annual',
                                 TRUE ~ frequency)) %>% 
    mutate(dataset_created = as.character(dataset_created),
           dataset_last_update = as.character(dataset_last_update)) %>% 
    mutate(report_creation_date = as.character(Sys.time() %>% 
                                                   with_tz(tzone = 'America/Los_Angeles')))


# resource level metadata -------------------------------------------------
## extract resource metadata ----
df_resources <- df_datasets %>% 
    select(resources) %>% 
    as.list()

df_resources <- df_resources$resources

## convert to single data frame ----
df_resources <- df_resources %>% 
    map(.f = ~ .x %>% mutate_all(as.character)) %>% 
    map_df(~.x) %>% 
    # type_convert() %>% 
    {.}

## format resource metadata ----
df_resources_format <- df_resources %>% 
    select('resource_name' = name,
           'resource_type' = format,
           'resource_last_update' = last_modified,
           'resource_created' = created, 
           'resource_download_url' = url,
           'resource_filename' = url, # modified below
           'resouce_description' = description, 
           datastore_active,
           datastore_contains_all_records_of_source_file,
           # position, # ?keep
           size, # ?what units?
           # ignore_hash,
           'resource_id' = id,
           'dataset_id' = package_id
    ) %>% 
    mutate(resource_created = resource_created %>% 
               ymd_hms() %>% 
               with_tz(tzone = 'America/Los_Angeles') %>% 
               # as.character() %>% 
               {.}) %>% 
    mutate(resource_last_update = resource_last_update %>% 
               ymd_hms() %>% 
               with_tz(tzone = 'America/Los_Angeles') %>% 
               # as.character() %>% 
               {.}) %>% 
    mutate(resource_last_update = case_when(
        is.na(resource_last_update) ~ min(resource_created, na.rm = TRUE),
        TRUE ~ resource_last_update)) %>% 
    mutate(resource_last_update_within = case_when(
        resource_last_update >= today() - 1 ~ '1 Day', # for last 24 hours: resource_last_update >= now() - 60*60*24, 
        resource_last_update >= today() - 7 ~ '2 Days to 1 Week',
        resource_last_update >= add_with_rollback(today(), months(-1)) ~ '1 Week to 1 Month',
        resource_last_update >= add_with_rollback(today(), months(-3)) ~ '1 to 3 Months',
        resource_last_update >= add_with_rollback(today(), months(-6)) ~ '3 to 6 Months',
        resource_last_update >= add_with_rollback(today(), months(-12)) ~ '6 Months to 1 Year',
        resource_last_update < add_with_rollback(today(), months(-12)) ~ '> 1 Year')) %>%
    relocate(resource_last_update_within, 
             .after = resource_last_update) %>% 
    mutate(resource_filename = basename(resource_filename)) %>% 
    mutate(datastore_contains_all_records_of_source_file = case_when(
        tolower(datastore_active) == 'false' ~ NA_character_,
        tolower(datastore_active) == 'true' & tolower(datastore_contains_all_records_of_source_file) == 'true' ~ 'TRUE',
        tolower(datastore_active) == 'true' & tolower(datastore_contains_all_records_of_source_file) == 'false' ~ 'FALSE',
        TRUE ~ datastore_contains_all_records_of_source_file
    )) %>%
    mutate(resource_created = as.character(resource_created),
           resource_last_update = as.character(resource_last_update)) %>% 
    {.}


## add dataset metadata ----
df_resources_format <- df_resources_format %>% 
    left_join(df_datasets_format %>% 
                  select(dataset_name, author, frequency, dataset_id, 
                         dataset_url,
                         program_contact_name, program_contact_email), 
              by = 'dataset_id') %>% 
    relocate(dataset_name, 
             .after = resource_name) %>% 
    relocate(dataset_frequency = frequency, 
             .after = resource_last_update_within) %>% 
    relocate(program_contact_name, 
             program_contact_email,
             author,
             .before = resource_id) %>% 
    mutate(resource_url = paste0(dataset_url, '/resource/', resource_id)) %>% 
    relocate(resource_url, .before = resource_download_url) %>% 
    mutate(report_creation_date = as.character(Sys.time() %>% 
                                                   with_tz(tzone = 'America/Los_Angeles')))

# glimpse(df_resources_format)
# View(df_resources_format)

# df_resources_format %>%
#     filter(datastore_contains_all_records_of_source_file %in% c('FALSE', 'False') &
#                datastore_active %in% c('TRUE', 'True')) %>% 
#     View()



# remove unused data ------------------------------------------------------
rm(df_datasets, df_resources)
