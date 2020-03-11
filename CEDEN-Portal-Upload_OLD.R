# For automated updates, turn off by setting run_script to FALSE
    run_script <- TRUE
    if(run_script == TRUE) {
    
    # NOTE: To schedule this script to run automatically, go to 'Addins' and 'Schedule R scripts on...', then select 
    # the file that calls this script ("C:\\David\\Open_Data_Project\\__CA_DataPortal\\_Call_Scripts\\Call_SurfWater_Script.R.R")
    # and set the time/date option (make sure the date format is %m/%d/%Y)
    
# load packages
    library(ckanr) # this lets you work with the CKAN portal
    library(tidyverse)
    library(janitor)
    library(dplyr)
    library(lubridate)
    library(chunked)
    library(httr)

# working directory
    setwd('C:\\David\\Open_Data_Project\\__CA_DataPortal\\CEDEN\\Python_Script\\CEDEN_Datasets')

# enter the date appended to the output files - generally should be today's date
    file_date <- as.Date('2019-12-03') # Sys.Date() 

# get the data portal API key and set up the CKAN defaults
    # get the data portal API key saved in the local environment (it's available on data.ca.gov by going to your user profile)
        portal_key <- Sys.getenv('data_portal_key')
    # set the ckan defaults    
        ckanr_setup(url = 'https://data.ca.gov/', key = portal_key)

# define file names and associated resource IDs (from the data portal)
    ceden_resource_list <- list(
        # Sites - #1
            'All_CEDEN_Sites' = list('id' = 'a927cb45-0de1-47e8-96a5-a5290816797b'), # https://data.ca.gov/dataset/surface-water-sampling-location-information/resource/a927cb45-0de1-47e8-96a5-a5290816797b
        # Safe to Swim - #2-3
            'SafeToSwim' = list('id' = 'fd2d24ee-3ca9-4557-85ab-b53aa375e9fc'), # https://data.ca.gov/dataset/surface-water-fecal-indicator-bacteria-Results/resource/fd2d24ee-3ca9-4557-85ab-b53aa375e9fc
            'Sites_for_SafeToSwim' = list('id' = '4f41c529-a33f-4006-9cfc-71b6944cb951'), # https://data.ca.gov/dataset/surface-water-fecal-indicator-bacteria-Results/resource/4f41c529-a33f-4006-9cfc-71b6944cb951
        # Benthic - #4
            'BenthicData' = list('id' = '3dfee140-47d5-4e29-99ae-16b9b12a404f'), # https://data.ca.gov/dataset/surface-water-benthic-macroinvertebrate-Results/resource/3dfee140-47d5-4e29-99ae-16b9b12a404f
        # Habitat - #5-7
            'HabitatData_prior_to_2000'= list('id' = '1eef884f-9633-45e0-8efb-09d48333a496'), # https://data.ca.gov/dataset/surface-water-habitat-Results/resource/1eef884f-9633-45e0-8efb-09d48333a496
            'HabitatData_2000-2009' = list('id' = '5bc866af-c176-463c-b513-88f536d69a28'), # https://data.ca.gov/dataset/surface-water-habitat-Results/resource/5bc866af-c176-463c-b513-88f536d69a28
            'HabitatData_2010-present' = list('id' = 'fe54c1c5-c16b-4507-8b3b-d6563df98e95'), # https://data.ca.gov/dataset/surface-water-habitat-Results/resource/fe54c1c5-c16b-4507-8b3b-d6563df98e95
        # Tissue - #8-10
            'TissueData_prior_to_2000' = list('id' = 'ed646127-50e1-4163-8ff6-d30e8b8056b1'), # https://data.ca.gov/dataset/surface-water-aquatic-organism-tissue-sample-Results/resource/ed646127-50e1-4163-8ff6-d30e8b8056b1
            'TissueData_2000-2009' = list('id' = '6890b717-19b6-4b1f-adfb-9c2874c8012e'), # https://data.ca.gov/dataset/surface-water-aquatic-organism-tissue-sample-Results/resource/6890b717-19b6-4b1f-adfb-9c2874c8012e
            'TissueData_2010-present' = list('id' = '5d4d572b-004b-4e2b-b26c-20ef050c018f'), # https://data.ca.gov/dataset/surface-water-aquatic-organism-tissue-sample-Results/resource/5d4d572b-004b-4e2b-b26c-20ef050c018f
        # Toxicity - #11
            'ToxicityData' = list('id' = 'bd484e9b-426a-4ba6-ba4d-f5f8ce095836'), # https://data.ca.gov/dataset/surface-water-toxicity-Results/resource/bd484e9b-426a-4ba6-ba4d-f5f8ce095836
        # Water Chemistry - #12-14
            'WaterChemistryData_prior_to_2000' = list('id' = '158c8ca1-b02f-4665-99d6-2c1c15b6de5a'), # https://data.ca.gov/dataset/surface-water-chemistry-Results/resource/158c8ca1-b02f-4665-99d6-2c1c15b6de5a
            'WaterChemistryData_2000-2009' = list('id' = 'feb79718-52b6-4aed-8f02-1493e6187294'), # https://data.ca.gov/dataset/surface-water-chemistry-Results/resource/feb79718-52b6-4aed-8f02-1493e6187294
            'WaterChemistryData_2010-present' = list('id' = 'afaeb2b2-e26f-4d18-8d8d-6aade151b34a') # https://data.ca.gov/dataset/surface-water-chemistry-Results/resource/afaeb2b2-e26f-4d18-8d8d-6aade151b34a
    )


# write to the open data portal  
    for (i in seq(length(ceden_resource_list))) {
        # get the portal resource id
        resourceID <- ceden_resource_list[[i]][[1]]
        # get resource info (just as a check)
        ckan_resource_info <- resource_show(id = resourceID, as = 'table')
        # get the name of the file to write to the portal
        out_file <- paste0('.\\' , names(ceden_resource_list[i]), '_', file_date, '.csv')
        # write to the portal
        # ptm <- proc.time()
        file_upload <- ckanr::resource_update(id = resourceID, path = out_file) # , ... = httr::config(accepttimeout_ms = 120000))
        # proc.time() - ptm
    }

}
