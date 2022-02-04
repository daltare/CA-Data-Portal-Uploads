# get metadata for all Waterboards datasets (i.e., collections of data resources) 
# on the CA open data portal (data.ca.gov)


# load libraries ----------------------------------------------------------
library(dplyr)
library(ckanr)
library(readr)
library(writexl)
library(here)
library(tcltk)
library(blastula)
library(sendmailR)



# user inputs -------------------------------------------------------------
# define location where files will be saved
file_save_location <- 'C:\\David\\_CA_data_portal\\_Data-Portal-Report\\'
shared_drive_location <- 'S:\\OIMA\\SHARED\\Altare_D\\Data-Portal-Report\\CKAN-Data-Portal-Report_'

# get the data portal API key saved in the local environment (it's available on data.ca.gov by going to your user profile)
portal_key <- Sys.getenv('data_portal_key')



# get data ----------------------------------------------------------------
## set ckanr defaults ----
ckanr_setup(url = 'https://data.ca.gov/', 
            key = portal_key)

df_datasets <- package_search(q = 'owner_org:a652035f-505c-4c24-8464-fed3623acfcd', 
                    rows = 99999, as = 'table')
df_datasets <- df_datasets$results
glimpse(df_datasets)
# View(df_datasets)

df_datasets_format <- df_datasets %>% 
    filter(!private) %>% # show only public datasets
    select(title,
           'link' = name,
           num_resources,
           author, 
           # author_email,
           'program_contact_name' = contact_name, 
           'program_contact_email' = contact_email, 
           # maintainer, maintainer_email,
           'homepage_url' = landingPage,
           'source_link' = url,
           'created' = metadata_created, 
           'last_updated' = metadata_modified,
           'description' = notes,
           additional_information,
           related_resources,
           secondary_sources,
           'temporal_coverage' = temporal,
           granularity,
           'geographic_coverage_location' = geo_coverage,
           'frequency' = accrualPeriodicity, 
           language,
           rights,
           'data_standard' = conformsTo,
           group,
           citation) %>% 
    arrange(title) %>% 
    mutate(link = paste0('https://data.ca.gov/dataset/', link))
View(df_datasets_format)



# write to excel file -----------------------------------------------------
write_xlsx(x = df_datasets_format, path = here('datasets_info.xlsx'))

