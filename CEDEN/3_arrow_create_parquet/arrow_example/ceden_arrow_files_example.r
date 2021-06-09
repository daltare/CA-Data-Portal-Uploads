# This example shows how to work with CEDEN data in the Apache parquet file format, using the arrow package in R 
# The data (in parquet file format) for each type of CEDEN data is available on the California Open Data Portal at the 
# following links: 
    # Water Chemistry: https://data.ca.gov/dataset/surface-water-chemistry-results/resource/f4aa224d-4a59-403d-aad8-187955aa2e38
    # Habitat: https://data.ca.gov/dataset/surface-water-habitat-results/resource/0184c4d0-1e1d-4a33-92ad-e967b5491274
    # Tissue: https://data.ca.gov/dataset/surface-water-aquatic-organism-tissue-sample-results/resource/dea5e450-4196-4a8a-afbb-e5eb89119516
    # Toxicity: https://data.ca.gov/dataset/surface-water-toxicity-results/resource/a6c91662-d324-43c2-8166-a94dddd22982
    # Benthic Macroinvertebrates: https://data.ca.gov/dataset/surface-water-benthic-macroinvertebrate-results/resource/eb61f9a1-b1c6-4840-99c7-420a2c494a43

# load packages
library(arrow)
library(dplyr)
library(tictoc)
library(glue)
library(zip)
library(tools)

# enter the URL to the zip file containing the parquet files for one of the CEDEN data types
# this example uses the water chemistry dataset -- replace this URL with one of the URLs above to access a different CEDEN data type
    # NOTE: be sure to replace the file name at the end of this link with the current version of the file name (you can also use the ckanr 
    # package's resource_show() function to retrieve the current filename -- e.g., for this dataset use: 
    # ckanr::resource_show(id = 'f4aa224d-4a59-403d-aad8-187955aa2e38', url = 'https://data.ca.gov')$url
data_url <- 'https://data.ca.gov/dataset/28d7a81d-6458-47bd-9b79-4fcbfbb88671/resource/f4aa224d-4a59-403d-aad8-187955aa2e38/download/ceden_chemistry_2021-02-08.zip'
    
# download the zip file to a temporary directory, and unzip to the working directory ----
    zip_file_name <- basename(data_url)
    directory_name <- file_path_sans_ext(zip_file_name)

    # create temporary directory
    temp_dir <- tempdir()
    
    # download to temporary directory
    download.file(url = data_url, 
                  destfile = file.path(temp_dir, zip_file_name),
                  mode = 'wb')

    # unzip to working directory
    zip::unzip(zipfile = file.path(temp_dir, zip_file_name), 
               exdir = directory_name)


# create a connection to the dataset (with Arrow) ----
    ds_con <- open_dataset(directory_name, partitioning = "year")

    
#### EXAMPLE QUERIES ####
# (NOTE: these queries use the CEDEN water chemistry dataset, but the same general process can be used for any dataset)

# Example query: pull E. coli data from 2010 to present, remove samples with certain station codes (which indicate QA data), and just select a few fields ----
    tic() # start timer
    ds_con %>% 
        filter(Analyte %in% c("E. coli"), # get E. coli data
               year >= 2010, # just get data from year 2010 through present
               !(StationCode %in% c('LABQA_SWAMP', '0000', '000NONPJ'))) %>% # remove QA data
        select(StationCode, SampleDate, Analyte, Unit, Result, MDL, RL, year) %>% # just get certain fields
        collect() # get the data
    toc() # stop timer
    
    # 1.09 sec elapsed
    
    # # A tibble: 144,222 x 8
    #    StationCode SampleDate          Analyte Unit       Result   MDL    RL  year
    #    <chr>       <dttm>              <chr>   <chr>       <dbl> <dbl> <dbl> <int>
    #  1 HSC-GHS     2010-06-12 00:00:00 E. coli MPN/100 mL    3.1   -88     1  2010
    #  2 MVC-LIB     2010-06-12 00:00:00 E. coli MPN/100 mL   14     -88     1  2010
    #  3 MVC-USFS    2010-06-12 00:00:00 E. coli MPN/100 mL   15     -88     1  2010
    #  4 BAKER NE    2010-08-04 00:00:00 E. coli MPN/100 mL   10     -88   -88  2010
    #  5 BAKER NE    2010-08-18 00:00:00 E. coli MPN/100 mL   10     -88   -88  2010
    #  6 BAKER NE    2010-09-15 00:00:00 E. coli MPN/100 mL   20     -88   -88  2010
    #  7 BAKER NE    2010-10-20 00:00:00 E. coli MPN/100 mL   10     -88   -88  2010
    #  8 BAKER NW    2010-04-21 00:00:00 E. coli MPN/100 mL   63     -88   -88  2010
    #  9 BAKER NW    2010-05-12 00:00:00 E. coli MPN/100 mL   10     -88   -88  2010
    # 10 BAKER NW    2010-05-19 00:00:00 E. coli MPN/100 mL   41     -88   -88  2010
    # # ... with 144,212 more rows
    

# Example query: pull E. coli data for all years, remove QA data, and calculate average result for each station, unit, and year ----
    tic() # start timer
    ds_con %>% 
        select(StationCode, Analyte, Unit, Result, year) %>%
        filter(Analyte %in% c("E. coli"), # get E. coli data
               !(StationCode %in% c('LABQA_SWAMP', '0000', '000NONPJ'))) %>%  # remove QA data
        group_by(StationCode, Analyte, Unit, year) %>% # group data for the calculations below
        collect() %>% # get the data
        summarize(avg_result = mean(Result, na.rm = TRUE), # calculate the average for each station, unit, and year
                  n = n()) 
    toc() # stop timer

    # 1.89 sec elapsed
    
    # # A tibble: 15,688 x 6
    # # Groups:   StationCode, Analyte, Unit [4,171]
    #    StationCode  Analyte Unit        year avg_result     n
    #    <chr>        <chr>   <chr>      <int>      <dbl> <int>
    #  1 01T_ODD3_EDI E. coli MPN/100 mL  2017       464.     5
    #  2 01T_ODD3_EDI E. coli MPN/100 mL  2018     44569.     5
    #  3 01T_ODD3_EDI E. coli MPN/100 mL  2019       548      6
    #  4 01T_ODD3_EDI E. coli MPN/100 mL  2020       645      2
    #  5 05T_HONDO    E. coli MPN/100 mL  2017      3410      1
    #  6 05T_HONDO    E. coli MPN/100 mL  2018     13340      1
    #  7 05T_HONDO    E. coli MPN/100 mL  2019      9565      2
    #  8 06T_LONG2    E. coli MPN/100 mL  2017     14670      1
    #  9 06T_LONG2    E. coli MPN/100 mL  2018     12230      1
    # 10 06T_LONG2    E. coli MPN/100 mL  2019      6570      1
    # # ... with 15,678 more rows

    
# Example query: get all E. coli data (including all fields) within a selected date range for a (randomly chose) station ----
    tic() # start timer
    df_query_data <- ds_con %>% 
        filter(SampleDate >= '2016-07-01',
               SampleDate <= '2018-06-30',
               Analyte == "E. coli",
               StationName == 'BAY#301.1_SL-Candlestick Point, San Francisco') %>% 
        collect() 
    toc() # stop timer
    
    # 3.33 sec elapsed
    
    # verify the correct dates/analyte/station was returned
    range(df_query_data$SampleDate)
    # [1] "2016-07-05 UTC" "2018-06-25 UTC"
    
    df_query_data %>% count(Analyte, StationName)
    # # A tibble: 1 x 3
    #   Analyte StationName                                       n
    #   <chr>   <chr>                                         <int>
    # 1 E. coli BAY#301.1_SL-Candlestick Point, San Francisco   161
