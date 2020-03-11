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
    # library(dplyr)
    library(lubridate)
    library(chunked)
    library(httr)

        
# enter the date appended to the output files - generally should be today's date
    file_date <- Sys.Date() # as.Date('2020-01-15') #         
        
# working directory
    setwd('C:\\David\\Open_Data_Project\\__CA_DataPortal\\CEDEN\\Python_Script\\CEDEN_Datasets\\')
    
# get the data portal API key and set up the CKAN defaults
    # get the data portal API key saved in the local environment (it's available on data.ca.gov by going to your user profile)
        portal_key <- Sys.getenv('data_portal_key')
    # set the ckan defaults    
        ckanr_setup(url = 'https://data.ca.gov/', key = portal_key)
    
# define file names and associated resource IDs (from the data portal)
    ceden_resource_list <- list(# Sites - #1
                                'All_CEDEN_Sites' = list('id' = 'a927cb45-0de1-47e8-96a5-a5290816797b', # https://data.ca.gov/dataset/surface-water-sampling-location-information/resource/a927cb45-0de1-47e8-96a5-a5290816797b
                                                         'fields_numeric' = c('Latitude', 'Longitude'),
                                                         'fields_time' = c(),
                                                         'fields_date' <- c()),
                                # Safe to Swim - #2-3
                                'SafeToSwim' = list('id' = 'fd2d24ee-3ca9-4557-85ab-b53aa375e9fc', # https://data.ca.gov/dataset/surface-water-fecal-indicator-bacteria-Results/resource/fd2d24ee-3ca9-4557-85ab-b53aa375e9fc
                                                    'fields_numeric' = c('CollectionDepth', 'CollectionReplicate', 'ResultsReplicate',
                                                                         'Result', 'MDL', # 'observation',
                                                                         'RL', 'GroupSamples', 'Latitude',
                                                                         'Longitude', 'DilutionFactor', 'DistanceFromBank',
                                                                         'StreamWidth', 'StationWaterDepth', 'ChannelWidth',
                                                                         'UpstreamLength', 'DownStreamLength','TotalReach'),
                                                    'fields_time' = c('CollectionTime'),
                                                    'fields_date' <- c('SampleDate', 'CalibrationDate', 'PrepPreservationDate',
                                                                       'DigestExtractDate', 'AnalysisDate')),
                                'Sites_for_SafeToSwim' = list('id' = '4f41c529-a33f-4006-9cfc-71b6944cb951', # https://data.ca.gov/dataset/surface-water-fecal-indicator-bacteria-Results/resource/4f41c529-a33f-4006-9cfc-71b6944cb951
                                                              'fields_numeric' = c('Latitude', 'Longitude'),
                                                              'fields_time' = c(),
                                                              'fields_date' <- c()),
                                # Benthic - #4
                                'BenthicData' = list('id' = '3dfee140-47d5-4e29-99ae-16b9b12a404f', # https://data.ca.gov/dataset/surface-water-benthic-macroinvertebrate-Results/resource/3dfee140-47d5-4e29-99ae-16b9b12a404f
                                                     'fields_numeric' = c('Latitude', 'Longitude', 'CollectionReplicate',
                                                                          'DistinctOrganism', 'Counts', 'BAResult',
                                                                          'CollectionDepth', 'GrabSize'),
                                                     'fields_time' = c('CollectionTime'),
                                                     'fields_date' <- c('SampleDate')),
                                # # Habitat - #5-7
                                # 'HabitatData'= list('id' = '059212f2-13e0-4015-b088-e60fd418e55a', # https://data.ca.gov/dataset/surface-water-habitat-results/resource/059212f2-13e0-4015-b088-e60fd418e55a
                                #                     'fields_numeric' = c('Latitude', 'Longitude', 'CollectionReplicate',
                                #                                          'DistinctOrganism', 'Counts', 'BAResult',
                                #                                          'CollectionDepth', 'GrabSize'),
                                #                     'fields_time' = c('CollectionTime'),
                                #                     'fields_date' <- c('SampleDate')),
                                'HabitatData_prior_to_2000'= list('id' = '1eef884f-9633-45e0-8efb-09d48333a496', # https://data.ca.gov/dataset/surface-water-habitat-Results/resource/1eef884f-9633-45e0-8efb-09d48333a496
                                                                  'fields_numeric' = c('Latitude', 'Longitude', 'CollectionReplicate',
                                                                                       'DistinctOrganism', 'Counts', 'BAResult',
                                                                                       'CollectionDepth', 'GrabSize'),
                                                                  'fields_time' = c('CollectionTime'),
                                                                  'fields_date' <- c('SampleDate')),
                                'HabitatData_2000-2009' = list('id' = '5bc866af-c176-463c-b513-88f536d69a28', # https://data.ca.gov/dataset/surface-water-habitat-Results/resource/5bc866af-c176-463c-b513-88f536d69a28
                                                               'fields_numeric' = c('Latitude', 'Longitude', 'CollectionReplicate',
                                                                                    'DistinctOrganism', 'Counts', 'BAResult',
                                                                                    'CollectionDepth', 'GrabSize'),
                                                               'fields_time' = c('CollectionTime'),
                                                               'fields_date' <- c('SampleDate')),
                                'HabitatData_2010-present' = list('id' = 'fe54c1c5-c16b-4507-8b3b-d6563df98e95', # https://data.ca.gov/dataset/surface-water-habitat-Results/resource/fe54c1c5-c16b-4507-8b3b-d6563df98e95
                                                                  'fields_numeric' = c('Latitude', 'Longitude', 'CollectionReplicate',
                                                                                       'DistinctOrganism', 'Counts', 'BAResult',
                                                                                       'CollectionDepth', 'GrabSize'),
                                                                  'fields_time' = c('CollectionTime'),
                                                                  'fields_date' <- c('SampleDate')),
                                # # Tissue - #8-10
                                # 'TissueData' = list('id' = 'c8da2b23-0a55-4d86-80b3-06f68db2684c', # https://data.ca.gov/dataset/surface-water-aquatic-organism-tissue-sample-results/resource/c8da2b23-0a55-4d86-80b3-06f68db2684c
                                #                     'fields_numeric' = c('Latitude', 'Longitude', 'NumberFishperComp',
                                #                                          'CompositeReplicate', 'ResultReplicate', 'Result',
                                #                                          'MDL', 'RL', 'DilutionFactor',
                                #                                          'WeightAvg(g)', 'TLMax(mm)', 'TLAvgLength(mm)',
                                #                                          'CompSizeCheck', 'SampleDateRangeDays', 'CompositeLatitude',
                                #                                          'CompositeLongitude', 'CollectionReplicate', 'TotalCount',
                                #                                          'ForkLength', 'TotalLength', 'OrganismWeight',
                                #                                          'Age', 'TissueWeight', 'CompositeWeight', 'TLMin(mm)'),
                                #                     'fields_time' = c('CollectionTime'),
                                #                     'fields_date' <- c('EarliestDateSampled', 'PrepPreservationDate', 'DigestExtractDate',
                                #                                        'AnalysisDate', 'LatestDateSampled', 'SampleDate',
                                #                                        'CompositeSampleDate', 'HomogonizedDate')),
                                'TissueData_prior_to_2000' = list('id' = 'ed646127-50e1-4163-8ff6-d30e8b8056b1', # https://data.ca.gov/dataset/surface-water-aquatic-organism-tissue-sample-Results/resource/ed646127-50e1-4163-8ff6-d30e8b8056b1
                                                                  'fields_numeric' = c('Latitude', 'Longitude', 'NumberFishperComp',
                                                                                       'CompositeReplicate', 'ResultReplicate', 'Result',
                                                                                       'MDL', 'RL', 'DilutionFactor',
                                                                                       'WeightAvg(g)', 'TLMax(mm)', 'TLAvgLength(mm)',
                                                                                       'CompSizeCheck', 'SampleDateRangeDays', 'CompositeLatitude',
                                                                                       'CompositeLongitude', 'CollectionReplicate', 'TotalCount',
                                                                                       'ForkLength', 'TotalLength', 'OrganismWeight',
                                                                                       'Age', 'TissueWeight', 'CompositeWeight', 'TLMin(mm)'),
                                                                  'fields_time' = c('CollectionTime'),
                                                                  'fields_date' <- c('EarliestDateSampled', 'PrepPreservationDate', 'DigestExtractDate',
                                                                                     'AnalysisDate', 'LatestDateSampled', 'SampleDate',
                                                                                     'CompositeSampleDate', 'HomogonizedDate')),
                                'TissueData_2000-2009' = list('id' = '6890b717-19b6-4b1f-adfb-9c2874c8012e', # https://data.ca.gov/dataset/surface-water-aquatic-organism-tissue-sample-Results/resource/6890b717-19b6-4b1f-adfb-9c2874c8012e
                                                              'fields_numeric' = c('Latitude', 'Longitude', 'NumberFishperComp',
                                                                                   'CompositeReplicate', 'ResultReplicate', 'Result',
                                                                                   'MDL', 'RL', 'DilutionFactor',
                                                                                   'WeightAvg(g)', 'TLMax(mm)', 'TLAvgLength(mm)',
                                                                                   'CompSizeCheck', 'SampleDateRangeDays', 'CompositeLatitude',
                                                                                   'CompositeLongitude', 'CollectionReplicate', 'TotalCount',
                                                                                   'ForkLength', 'TotalLength', 'OrganismWeight',
                                                                                   'Age', 'TissueWeight', 'CompositeWeight', 'TLMin(mm)'),
                                                              'fields_time' = c('CollectionTime'),
                                                              'fields_date' <- c('EarliestDateSampled', 'PrepPreservationDate', 'DigestExtractDate',
                                                                                 'AnalysisDate', 'LatestDateSampled', 'SampleDate',
                                                                                 'CompositeSampleDate', 'HomogonizedDate')),
                                'TissueData_2010-present' = list('id' = '5d4d572b-004b-4e2b-b26c-20ef050c018f', # https://data.ca.gov/dataset/surface-water-aquatic-organism-tissue-sample-Results/resource/5d4d572b-004b-4e2b-b26c-20ef050c018f
                                                                 'fields_numeric' = c('Latitude', 'Longitude', 'NumberFishperComp',
                                                                                      'CompositeReplicate', 'ResultReplicate', 'Result',
                                                                                      'MDL', 'RL', 'DilutionFactor',
                                                                                      'WeightAvg(g)', 'TLMax(mm)', 'TLAvgLength(mm)',
                                                                                      'CompSizeCheck', 'SampleDateRangeDays', 'CompositeLatitude',
                                                                                      'CompositeLongitude', 'CollectionReplicate', 'TotalCount',
                                                                                      'ForkLength', 'TotalLength', 'OrganismWeight',
                                                                                      'Age', 'TissueWeight', 'CompositeWeight', 'TLMin(mm)'),
                                                                 'fields_time' = c('CollectionTime'),
                                                                 'fields_date' <- c('EarliestDateSampled', 'PrepPreservationDate', 'DigestExtractDate',
                                                                                    'AnalysisDate', 'LatestDateSampled', 'SampleDate',
                                                                                    'CompositeSampleDate', 'HomogonizedDate')),
                                # # Toxicity - #11
                                'ToxicityData' = list('id' = 'bd484e9b-426a-4ba6-ba4d-f5f8ce095836', # https://data.ca.gov/dataset/surface-water-toxicity-Results/resource/bd484e9b-426a-4ba6-ba4d-f5f8ce095836
                                                      'fields_numeric' = c('CollectionDepth', 'CollectionReplicate', 'lab_Replicate',
                                                                           'Result', 'Latitude', 'Longitude',
                                                                           'Dilution', 'TreatmentConcentration', 'DistanceFromBank',
                                                                           'StreamWidth', 'StationWaterDepth', 'PctControl',
                                                                           'RepCount', 'Mean', 'StdDev',
                                                                           'Alphalevel', 'EvalThreshold', 'MSD',
                                                                           'ChannelWidth', 'UpstreamLength', 'DownstreamLength',
                                                                           'TotalReach', 'CalculatedValue', 'PercentEffect'),
                                                      'fields_time' = c('CollectionTime'),
                                                      'fields_date' <- c('SampleDate', 'ToxBatchStartDate')),
                                # # Water Chemistry - #12-14
                                # 'WaterChemistryData' = list('id' = '5d754b3f-8286-4200-9985-2d917958ebf6' , # https://data.ca.gov/dataset/surface-water-chemistry-results/resource/5d754b3f-8286-4200-9985-2d917958ebf6
                                #                             'fields_numeric' = c('CollectionDepth', 'CollectionReplicate', 'ResultsReplicate',
                                #                                                  'Result', 'MDL', # 'Observation',
                                #                                                  'RL', 'GroupSamples', 'Latitude',
                                #                                                  'Longitude', 'DilutionFactor', 'DistanceFromBank',
                                #                                                  'StreamWidth', 'StationWaterDepth', 'ChannelWidth',
                                #                                                  'UpstreamLength', 'DownStreamLength','TotalReach'),
                                #                             'fields_time' = c('CollectionTime'),
                                #                             'fields_date' <- c('SampleDate', 'CalibrationDate', 'PrepPreservationDate',
                                #                                                'DigestExtractDate', 'AnalysisDate')),
                                'WaterChemistryData_prior_to_2000' = list('id' = '158c8ca1-b02f-4665-99d6-2c1c15b6de5a' , # https://data.ca.gov/dataset/surface-water-chemistry-Results/resource/158c8ca1-b02f-4665-99d6-2c1c15b6de5a
                                                                          'fields_numeric' = c('CollectionDepth', 'CollectionReplicate', 'ResultsReplicate',
                                                                                               'Result', 'MDL', # 'Observation',
                                                                                               'RL', 'GroupSamples', 'Latitude',
                                                                                               'Longitude', 'DilutionFactor', 'DistanceFromBank',
                                                                                               'StreamWidth', 'StationWaterDepth', 'ChannelWidth',
                                                                                               'UpstreamLength', 'DownStreamLength','TotalReach'),
                                                                          'fields_time' = c('CollectionTime'),
                                                                          'fields_date' <- c('SampleDate', 'CalibrationDate', 'PrepPreservationDate',
                                                                                             'DigestExtractDate', 'AnalysisDate')),
                                'WaterChemistryData_2000-2009' = list('id' = 'feb79718-52b6-4aed-8f02-1493e6187294', # https://data.ca.gov/dataset/surface-water-chemistry-Results/resource/feb79718-52b6-4aed-8f02-1493e6187294
                                                                      'fields_numeric' = c('CollectionDepth', 'CollectionReplicate', 'ResultsReplicate',
                                                                                           'Result', 'MDL', # 'Observation',
                                                                                           'RL', 'GroupSamples', 'Latitude',
                                                                                           'Longitude', 'DilutionFactor', 'DistanceFromBank',
                                                                                           'StreamWidth', 'StationWaterDepth', 'ChannelWidth',
                                                                                           'UpstreamLength', 'DownStreamLength','TotalReach'),
                                                                      'fields_time' = c('CollectionTime'),
                                                                      'fields_date' <- c('SampleDate', 'CalibrationDate', 'PrepPreservationDate',
                                                                                         'DigestExtractDate', 'AnalysisDate')),
                                'WaterChemistryData_2010-present' = list('id' = 'afaeb2b2-e26f-4d18-8d8d-6aade151b34a', # https://data.ca.gov/dataset/surface-water-chemistry-Results/resource/afaeb2b2-e26f-4d18-8d8d-6aade151b34a
                                                                         'fields_numeric' = c('CollectionDepth', 'CollectionReplicate', 'ResultsReplicate',
                                                                                              'Result', 'MDL', # 'Observation',
                                                                                              'RL', 'GroupSamples', 'Latitude',
                                                                                              'Longitude', 'DilutionFactor', 'DistanceFromBank',
                                                                                              'StreamWidth', 'StationWaterDepth', 'ChannelWidth',
                                                                                              'UpstreamLength', 'DownStreamLength','TotalReach'),
                                                                         'fields_time' = c('CollectionTime'),
                                                                         'fields_date' <- c('SampleDate', 'CalibrationDate', 'PrepPreservationDate',
                                                                                            'DigestExtractDate', 'AnalysisDate'))
                                )


# loop through the files
    for (i in seq(length(ceden_resource_list))) {
        # read the file into R
            out_file <- paste0(file_date, '\\', names(ceden_resource_list[i]), '_', file_date, '.csv')
            df_original <- readr::read_csv(out_file, guess_max = 999999) 
        # check dataset for portal compatibility and adjust as needed
            # clean up the names
                df_working <- df_original # clean_names(df_original)
            # view summary of the data
                glimpse(df_working)
            # reformat time fields
                fields_t <- ceden_resource_list[[i]][[3]]
                if (length(fields_t) > 0) {
                    for (counter_t in seq(length(fields_t))) {
                        df_working[,fields_t[counter_t]] <- paste(sep = ':', 
                                                                  str_pad(hour(df_working[[fields_t[counter_t]]]), width = 2, pad = 0), 
                                                                  str_pad(minute(df_working[[fields_t[counter_t]]]), width = 2, pad = 0), 
                                                                  str_pad(second(df_working[[fields_t[counter_t]]]), width = 2, pad = 0))
                    }
                }

        # date fields - convert dates into a format that can be recognized as timestamp type by the portal (NOTE: Not adding any time element to these records though)
            fields_d <- ceden_resource_list[[i]][[4]]
            if (length(fields_d) > 0) {
                    for (counter_d in seq(length(fields_d))) {
                        # convert the date field to ISO format
                            if (names(ceden_resource_list[i]) == 'ToxicityData' & counter_d == 2) {
                                dates_iso <- mdy_hm(df_working[[fields_d[counter_d]]])
                            } else if (is.character(df_working[[fields_d[counter_d]]])) {
                                dates_iso <- mdy(df_working[[fields_d[counter_d]]])
                            } else if (is.Date(df_working[[fields_d[counter_d]]]) | is.POSIXt(df_working[[fields_d[counter_d]]])) {
                                dates_iso <- as.Date(df_working[[fields_d[counter_d]]])
                            } 
                            # Convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
                                dates_iso <- as.character(dates_iso)
                                    # Check: sum(is.na(dates_iso))
                                dates_iso[is.na(dates_iso)] <- ''
                                    # check NAs: sum(is.na(dates_iso))
                                # Insert the revised date field back into the dataset
                                    df_working[,fields_d[counter_d]] <- dates_iso
                    }
            }

        # numeric fields - ensure all records are compatible with numeric format 
            # convert to numeric
                fields_n <- ceden_resource_list[[i]][[2]]
                if (length(fields_n) > 0) {
                    for (counter_n in seq(length(fields_n))) {
                        df_working[,fields_n[counter_n]] <- as.numeric(df_working[[fields_n[counter_n]]])
                    }
                }
                
        
        # # add a collection timestamp field
        #     df_habitat <- df_habitat %>% mutate(sample_timestamp = ymd_hms(paste(SampleDate, CollectionTime)))
        # # date/timestamp fields - convert dates into a timestamp field that can be read by the portal
        #     fields_dates <- c('sample_timestamp')
        #      for (counter in seq(length(fields_dates))) {
        #          if(sum(is.na(df_habitat[[fields_dates[counter]]])) > 0) {
        #             # convert the date field to ISO format
        #                 dates_iso <- ymd_hms(df_habitat[[fields_dates[counter]]])
        #                     # check NAs: sum(is.na(dates_iso))
        #                 if (sum(is.na(dates_iso)) > 0) {
        #                     # Convert dates to text, and for NAs store as '' (empty text string) - this converts to 'null' in Postgres
        #                         dates_iso <- as.character(dates_iso)
        #                             # Check: sum(is.na(dates_iso))
        #                         dates_iso[is.na(dates_iso)] <- ''
        #                             # check NAs: sum(is.na(dates_iso))
        #                     # Insert the revised date field back into the dataset
        #                         df_habitat[,fields_dates[counter]] <- dates_iso
        #             }
        #         }
        #     }

        # Convert missing values in text fields to 'NA' (to avoid converting to NaN) !!!!!!!!!!!
            # from: https://community.rstudio.com/t/using-case-when-over-multiple-columns/17206/2
            df_working <- df_working %>% mutate_if(is.character, list(~case_when(is.na(.) ~ 'NA', TRUE ~ .)))


    # write out the revised dataset as a .csv file
        if (!dir.exists(paste0('.\\portal-formatted\\', file_date))) {
            dir.create(paste0('.\\portal-formatted\\', file_date))
        }
        out_file <- paste0('.\\portal-formatted\\', file_date, '\\', names(ceden_resource_list[i]), '_', file_date, '.csv')
        write_csv(x = df_working, path = out_file, na = 'NaN')
    }    


# write to the open data portal
    # for (i in seq(length(ceden_resource_list))) {
    # for (i in 14:length(ceden_resource_list)) {
    #     # get the portal resource id
    #         resourceID <- ceden_resource_list[[i]][[1]]
    #     # get resource info (just as a check)
    #         ckan_resource_info <- resource_show(id = resourceID, as = 'table')
    #     # get the name of the file to write to the portal
    #         out_file <- paste0('.\\portal-formatted\\' , file_date, '\\', names(ceden_resource_list[i]), '_', file_date, '.csv')
    #     # write to the portal
    #         # ptm <- proc.time()
    #         file_upload <- ckanr::resource_update(id = resourceID, path = out_file) # , ... = httr::config(accepttimeout_ms = 120000))
    #         # proc.time() - ptm
    # }
    
    # load using python script for chunked uploads
        import('click')
        import('json')
        import('math')
        import('os')
        import('requests')
        import('requests_toolbelt')
        import('datetime')
        py_run_file("C:\\David\\Open_Data_Project\\__CA_DataPortal\\CEDEN\\portal-upload-ckan-chunked_CEDEN\\main_CEDEN.py")

}





# # TESTING ------------------------------------------------------------------------------------------------------------------#
# # define file paths
#     file_list <- c('All_CEDEN_Sites', 'BenthicData', 'HabitatData', 'SafeToSwim', 'Sites_for_SafeToSwim',
#                    'TissueData', 'ToxicityData', 'WaterChemistryData', 'WQX_Stations')
# 
#     file_list <- list('All_CEDEN_Sites' = 'a927cb45-0de1-47e8-96a5-a5290816797b',
#                       'BenthicData' = '3dfee140-47d5-4e29-99ae-16b9b12a404f', 
#                       # 'HabitatData' = 'aaa', 
#                       'SafeToSwim' = 'fd2d24ee-3ca9-4557-85ab-b53aa375e9fc', 
#                       'Sites_for_SafeToSwim' = '4f41c529-a33f-4006-9cfc-71b6944cb951',
#                       # 'TissueData' = 'aaa', 
#                       'ToxicityData' = 'bd484e9b-426a-4ba6-ba4d-f5f8ce095836'#, 
#                       # 'WaterChemistryData' = 'aaa')
#                       )    
#     
#     
# # TISSUE
# resourceID <- '780744ea-2e60-4d30-8def-3202f8d90cba'
# out_file <- "C:\\David\\Open_Data_Project\\__CA_DataPortal\\CEDEN\\Python_Script\\CEDEN_Datasets\\TissueData_prior_to_1999_2019-10-17.csv"
# 
# # HABITAT
# resourceID <- '9366f2a1-8b48-46f8-b8a8-548576e547de'
# out_file <- "C:\\David\\Open_Data_Project\\__CA_DataPortal\\CEDEN\\Python_Script\\CEDEN_Datasets\\HabitatData_2019-10-17.csv"
#         
#     
# # read chunked
# z <- readr::read_csv("C:\\David\\Open_Data_Project\\__CA_DataPortal\\CEDEN\\Python_Script\\CEDEN_Datasets\\HabitatData_prior_to_1999_2019-10-17.csv")
# 
# read_csv_chunkwise(file = "C:\\David\\Open_Data_Project\\__CA_DataPortal\\CEDEN\\Python_Script\\CEDEN_Datasets\\HabitatData_prior_to_1999_2019-10-17.csv") %>% 
#     write_chunkwise(dest = "C:\\Users\\daltare\\Desktop\\DELETE\\HabitatData_prior_to_1999_2019-10-17_chunk.csv")
# 
# zz <- readr::read_csv("C:\\Users\\daltare\\Desktop\\DELETE\\HabitatData_prior_to_1999_2019-10-17_chunk.csv")
# 
# glimpse(z)
# glimpse(zz)
# 
# 
# # sites
#     z_sites <- readr::read_csv("C:\\David\\Open_Data_Project\\__CA_DataPortal\\CEDEN\\Python_Script\\CEDEN_Datasets\\All_CEDEN_Sites_2019-10-17.csv", guess_max = 999999)
#         sum(is.na(z_sites$Longitude))
#         sum(is.na(z_sites$Latitude))
#         
#     # numeric fields - ensure all records are compatible with numeric format 
#         fields_numeric <- c('Latitude', 'Longitude')
#         # convert to numeric
#             for (counter in seq(length(fields_numeric))) {
#                 z_sites[,fields_numeric[counter]] <- as.numeric(df.data_filter[[fields_numeric[counter]]])
#             }
#     # chunks
#         read_csv_chunkwise(file = 'All_CEDEN_Sites_2019-10-17.csv') %>% 
#             mutate(Latitude = as.numeric(Latitude),
#                    Longitude = as.numeric(Longitude)) %>% 
#             write_csv_chunkwise(file = 'All_CEDEN_Sites_2019-10-17_FORMATTED.csv')#, na = 'NaN')
#         
#         
#         z <- read_chunkwise(file = 'All_CEDEN_Sites_2019-10-17.csv')
#         
#         abc <- read_chunkwise(src = 'All_CEDEN_Sites_2019-10-17.csv', fill = TRUE, header = TRUE, quote = "\"", comment.char = '')
#         
#         f <- function(x, pos) {filter(x, Latitude > 0)}
#         zz <- read_csv_chunked(file = 'All_CEDEN_Sites_2019-10-17.csv', callback = DataFrameCallback$new(f))
#         
# # benthic
#     z_benthic <- read_csv('BenthicData_2019-10-17.csv', guess_max = 999999)
#     
#     
#     
# 
#     # for (i in seq(length(file_list))) {
#     #     out_file <- paste0('C:\\David\\Open_Data_Project\\__CA_DataPortal\\CEDEN\\Python_Script\\CEDEN_Datasets\\', 
#     #                        names(file_list[i]), '_', file_date, '.csv')
#     #     file_upload <- resource_update(id = file_list[[i]], 
#     #                                    path = out_file)
#     # }