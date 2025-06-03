# this scripts automates all steps to update CEDEN data on the CA data portal 
# (data.ca.gov), and sends an automated email if any part of the process fails



# load packages ----------------------------------------------------------
{
    library(tidyverse)
    library(janitor)
    library(lubridate)
    library(glue)
    library(blastula)
    library(sendmailR)
    library(reticulate)
    library(here)
    library(checkpoint)
    library(gmailr)
    
    ## conflicts ----
    library(conflicted)
    conflicts_prefer(dplyr::filter, 
                     lubridate::year, 
                     magrittr::extract,
                     dplyr::last)
}



# 1 - user input --------------------------------------------------------------
{
    ## set path to save data files ----
    data_files_date <- Sys.Date() %>% as.character()
    data_files_path <- glue('C:/Users/daltare/Documents/ca_data_portal_temp/CEDEN/{data_files_date}/')
    
    ## automated email ----
    ### send email if process fails? ----
    send_failure_email <- TRUE # may be useful to set this to FALSE (ie turn off emails) if the email functions fail (this especially may be the case when on the VPN)
    
    ### email address (to send warning emails to/from) ----
    ### NOTE - if sending from a personal email address, you'll have to update the credentials -- see below
    ### email address to send warning emails from
    email_from <- 'daltare.swrcb@gmail.com' # 'david.altare@waterboards.ca.gov' # "gisscripts-noreply@waterboards.ca.gov"
    
    ### create credentials file (only need to do this once) ----
    ### gmail credentials ----
    #### NOTE - for gmail, you have to create an 'App Password' and use that 
    #### instead of your normal password - see: 
    #### (https://support.google.com/accounts/answer/185833?hl=en) 
    #### Background here:
    #### https://github.com/rstudio/blastula/issues/228 
    # create_smtp_creds_file(file = credentials_file,
    #                        user = email_from,
    #                        provider = 'gmail'
    #                        )
    credentials_file <- 'gmail_creds' # this is the credentials file to be used (corresponds to the email_from address)
    
    ### email address (or addresses) to send warning emails to
    email_to <- 'david.altare@waterboards.ca.gov' # c('david.altare@waterboards.ca.gov', 'waterdata@waterboards.ca.gov')
    
    ### email subject line ----
    subject_line <- "Data Portal Upload Error (CEDEN Data)"
    
    ## data portal username and password ----
    portal_username <- Sys.getenv('portal_username') 
    portal_password <- Sys.getenv('portal_password')
    
    ## data portal API key ----
    #### key is saved in the local environment (it's available on data.ca.gov by going to your user profile)
    portal_key <- Sys.getenv('data_portal_key')
    
    ## ceden data warehouse info ----
    ceden_server <- Sys.getenv('ceden_server')
    ceden_id <- Sys.getenv('ceden_user_id')
    ceden_pwd <- Sys.getenv('ceden_password')
    
    ## python info ----
    # python_path <- 'C:\\Anaconda-3.7'
    
    ## define location of python script to upload chunked data (relative path)
    python_upload_script <- here('2_portal-upload-ckan-chunked_CEDEN', 
                                 'main_CEDEN_function.py')
    chunked_upload_directory <- '2_portal-upload-ckan-chunked_CEDEN'
    
    ## define files to be uploaded ----
    upload_files_list <- list(
        All_CEDEN_Sites = list(
            'all_sites' = 'a927cb45-0de1-47e8-96a5-a5290816797b'
        ),
        ToxicityData = list(
            'all_years' = 'bd484e9b-426a-4ba6-ba4d-f5f8ce095836'
        ),
        BenthicData = list(
            'all_years' = '3dfee140-47d5-4e29-99ae-16b9b12a404f'
        ),
        WaterChemistryData = list(
            'year-2025' = '97b8bb60-8e58-4c97-a07f-d51a48cd36d4',
            'year-2024' = '9dcf551f-452d-4257-b857-30fbcc883a03',
            'year-2023' = '6f9dd0e2-4e16-46c2-bed1-fa844d92df3c',
            'year-2022' = '5d7175c8-dfc6-4c43-b78a-c5108a61c053',
            'year-2021' = 'dde19a95-504b-48d7-8f3e-8af3d484009f',
            'year-2020' = '2eba14fa-2678-4d54-ad8b-f60784c1b234',
            'year-2019' = '6cf99106-f45f-4c17-80af-b91603f391d9',
            'year-2018' = 'f638c764-89d5-4756-ac17-f6b20555d694',
            'year-2017' = '68787549-8a78-4eea-b5b9-ef719e65a05c',
            'year-2016' = '42b906a2-9e30-4e44-92c9-0f94561e47fe',
            'year-2015' = '7d9384fa-70e1-4986-81d6-438ce5565be6',
            'year-2014' = '7abfde16-61b6-425d-9c57-d6bd70700603',
            'year-2013' = '341627e6-a483-4e9e-9a85-9f73b6ddbbba',
            'year-2012' = 'f9dd0348-85d5-4945-aa62-c7c9ad4cf6fd',
            'year-2011' = '4d01a693-2a22-466a-a60b-3d6f236326ff',
            'year-2010' = '572bf4d2-e83d-490a-9aa5-c1d574e36ae0',
            'year-2009' = '5b136831-8870-46f2-8f72-fe79c23d7118',
            'year-2008' = 'c587a47f-ac28-4f77-b85e-837939276a28',
            'year-2007' = '13e64899-df32-461c-bec1-a4e72fcbbcfa',
            'year-2006' = 'a31a7864-06b9-4a81-92ba-d8912834ca1d',
            'year-2005' = '9538cbfa-f8be-4445-97dc-b931579bb927',
            'year-2004' = 'c962f46d-6a7b-4618-90ec-3c8522836f28',
            'year-2003' = 'd3f59df4-2a8d-4b40-b90f-8147e73335d9',
            'year-2002' = '00c4ca34-064f-4526-8276-57533a1a36d9',
            'year-2001' = 'cec6768c-99d3-45bf-9e56-d62561e9939e',
            'year-2000' = '99402c9c-5175-47ca-8fce-cb6c5ecc8be6',
            'prior_to_2000' = '158c8ca1-b02f-4665-99d6-2c1c15b6de5a'
        ),
        TissueData = list(
            'year-2024' = 'fe359a58-d785-4d45-af72-5e8b0f5428ff',
            'year-2023' = '1512aa84-f18d-4c60-89a0-50c2d1cd1d0c',
            'year-2022' = '6754e8b7-9136-44aa-b65c-bf3a8af6be77',
            'year-2021' = '02e2e832-fa46-4ecb-98e8-cdb70fe3902d',
            'year-2020' = 'a3545e8e-2ab5-46b3-86d5-72a74fcd8261',
            'year-2019' = 'edd16b08-3d9f-4375-9396-dce7cbd2f717',
            'year-2018' = '559c5523-8883-4da0-9750-f7fd3f088cfb',
            'year-2017' = 'e30e6266-5978-47f4-ae6a-94336ab224f9',
            'year-2016' = 'c7a56123-8692-4d92-93cc-aa12d7ab46c9',
            'year-2015' = '3376163c-dcda-4b76-9672-4ecfee1e1417',
            'year-2014' = '8256f15c-8500-47c3-be34-d12b45b0bbe9',
            'year-2013' = 'eb2d102a-ecdc-4cbe-acb9-c11161ac74b6',
            'year-2012' = '8e3bbc50-dd72-4cee-b926-b00f488ff10c',
            'year-2011' = '06440749-3ada-4461-959f-7ac2699faeb0',
            'year-2010' = '82dbd8ec-4d59-48b5-8e10-ce1e41bbf62a',
            'year-2009' = 'c1357d10-41cb-4d84-bd3a-34e18fa9ecdf',
            'year-2008' = 'da39833c-9d62-4307-a93e-2ae8ad2092e3',
            'year-2007' = 'f88461cf-49b2-4c5c-ba2c-d9484202bc74',
            'year-2006' = 'f3ac3204-f0a2-4561-ae18-836b8aafebe8',
            'year-2005' = '77daaca9-3f47-4c88-9d22-daf9f79e2729',
            'year-2004' = '1dc7ed28-a59b-48a7-bc81-ef9582a4efaa',
            'year-2003' = '1a21e2ac-a9d8-4e81-a6ad-aa6636d064d1',
            'year-2002' = '6a56b123-9275-4549-a625-e5aa6f2b8b57',
            'year-2001' = '47df34fd-8712-4f72-89ff-091b3e954399',
            'year-2000' = '06b35b3c-6338-44cb-b465-ba4c1863b7c5',
            'prior_to_2000' = '97786a54-1189-43e4-9244-5dcb241dfa58'
        ),
        HabitatData = list(
            'year-2025' = '3e02cc4d-7a91-4348-9537-7597b0702f57',
            'year-2024' = 'a7bf7ff5-930e-417a-bc3e-1e1794cd2513',
            'year-2023' = '1f6b0641-3aac-48b2-b12f-fa2d4966adfd',
            'year-2022' = '0fcdfad7-6588-41fc-9040-282bac2147bf',
            'year-2021' = 'c82a3e83-a99b-49d8-873b-a39640b063fc',
            'year-2020' = 'bd37df2e-e6a4-4c2b-b01c-ce7840cc03de',
            'year-2019' = 'c0f230c5-3f51-4a7a-a3db-5eb8692654aa',
            'year-2018' = 'd814ca0c-ace1-4cc1-a80f-d63f138e2f61',
            'year-2017' = 'f7a33584-510f-46f8-a314-625f744ecbdd',
            'year-2016' = '01e35239-6936-4699-b9db-fda4751be6e9',
            'year-2015' = '115c55e3-40af-4734-877f-e197fdae6737',
            'year-2014' = '082a7665-8f54-4e4f-9d24-cc3506bb8f3e',
            'year-2013' = '3be276c3-9966-48de-b53a-9a98d9006cdb',
            'year-2012' = '78d44ee3-65af-4c83-b75e-8a82b8a1db88',
            'year-2011' = '2fa6d874-1d29-478a-a5dc-0c2d31230705',
            'year-2010' = '2a8b956c-38fa-4a15-aaf9-cb0fcaf915f3',
            'year-2009' = 'd025552d-de5c-4f8a-b2b5-a9de9e9c86c3',
            'year-2008' = 'ce211c51-05a2-4a7c-be18-298099a0dcd2',
            'year-2007' = '1659a2b4-21e5-4fc4-a9a4-a614f0321c05',
            'year-2006' = '88b33d5b-5428-41e2-b77b-6cb46ca5d1e4',
            'year-2005' = '1609e7ab-d913-4d24-a582-9ca7e8e82233',
            'year-2004' = 'e5132397-69a5-46fb-b24a-cd3b7a1fe53a',
            'year-2003' = '899f3ebc-538b-428e-8f1f-d591445a847c',
            'year-2002' = 'a9d8302d-0d37-4cf3-bbeb-386f6bd948a6',
            'year-2001' = 'ea8b0171-e226-4e80-991d-50752abea734',
            'year-2000' = 'b3dba1ee-6ada-42d5-9679-1a10b44630bc',
            'prior_to_2000' = 'a3dcc442-e722-495f-ad59-c704ae934848'
        )
    )
    
}



# 2 - setup automated email ---------------------------------------------------

## create email function ----
fn_send_email <- function(error_msg, error_msg_r) {
    
    ### create components ----
    #### date/time ----
    date_time <- add_readable_time()
    
    #### body ----
    body <- glue(
        "Hi,
There was an error uploading the CEDEN Data to the data.ca.gov portal on {Sys.Date()}.
                
------
                
The process failed at this step: *{error_msg}*

Here's the error message from R: *{glue_collapse(error_msg_r, sep = ' | ')}*

------
                
Here's the link to the datasets on the data portal: 

- Chemistry: https://data.ca.gov/dataset/surface-water-chemistry-results
- Toxicity: https://data.ca.gov/dataset/surface-water-toxicity-results
- Benthic: https://data.ca.gov/dataset/surface-water-benthic-macroinvertebrate-results
- Habitat: https://data.ca.gov/dataset/surface-water-habitat-results
- Tissue: https://data.ca.gov/dataset/surface-water-aquatic-organism-tissue-sample-results

The source data comes from the CEDEN data mart"                
    )
    
    #### footer ----
    footer <- glue("Email sent on {date_time}.")
    
    ### create email ----
    email <- compose_email(
        body = md(body),
        footer = md(footer)
    )
    
    ### send email via blastula (using credentials file) ----
    email %>%
        smtp_send(
            to = email_to,
            from = email_from,
            subject = subject_line,
            credentials = creds_file(credentials_file)
            # credentials = creds_key("outlook_key")
        )
    
    ### send email via sendmailR (for use on GIS scripting server) ----
    # from <- email_from
    # to <- email_to
    # sendmail(from,to,subject,body,control=list(smtpServer= ""))
    
    print('sent automated email')
}


## gmailr function ----
### NOTE: blastula may not work when on the waterboard VPN, but gmailr might
### (it's hard to tell if that will always be the case though)
### setting up gmailr is somewhat complicated, instructions are here:
### https://github.com/r-lib/gmailr 
### in particular note the OAuth steps: https://gmailr.r-lib.org/dev/articles/oauth-client.html
fn_email_gmailr <- function(error_msg, error_msg_r) {
    
    ### body ----
    body <- glue(
        "Hi,
There was an error uploading the CEDEN Data to the data.ca.gov portal on {Sys.Date()}.
                
------
                
The process failed at this step: *{error_msg}*

Here's the error message from R: *{glue_collapse(error_msg_r, sep = ' | ')}*

------
                
Here's the link to the datasets on the data portal: 

- Chemistry: https://data.ca.gov/dataset/surface-water-chemistry-results
- Toxicity: https://data.ca.gov/dataset/surface-water-toxicity-results
- Benthic: https://data.ca.gov/dataset/surface-water-benthic-macroinvertebrate-results
- Habitat: https://data.ca.gov/dataset/surface-water-habitat-results
- Tissue: https://data.ca.gov/dataset/surface-water-aquatic-organism-tissue-sample-results

The source data comes from the CEDEN data mart"                
    )
    
    email_message <-
        gm_mime() |>
        gm_to(email_to) |>
        gm_from(email_from) |>
        gm_subject(subject_line) |>
        gm_text_body(body)
    
    gm_send_message(email_message)
}



# 3 - download data -------------------------------------------------------
## set python version ----
# use_python(python_path)
# use_condaenv()
# reticulate::py_config() # gets information about current python version being used

Sys.sleep(1)

## define datasets to download ----
tables_list = c(
    "ToxicityData" = "ToxDmart_MV",
    "BenthicData" = "BenthicDMart_MV",
    "WaterChemistryData" = "WQDMart_MV",
    "TissueData" = "TissueDMart_MV",
    "HabitatData" = "HabitatDMart_MV"
)

## download 2023 to present ----
### NOTE: this only gets the 2023 - present data, as an individual file for each year;
### bulk files with data across all years are created with the process that downloads data 
### up through 2010
tryCatch(
    {
        gc()
        
        ### get python function
        #### install dependent python packages
        setwd(here('1_data_download'))
        shell('pip install -r requirements_CEDEN.txt')
        setwd('..')
        
        ### get python function
        source_python(here('1_data_download', 
                           'CEDEN_DataRefresh_yearly_2023-to-present_function.py')) 
        
        ### get data
        for (data_type in names(tables_list)) {
            Sys.sleep(1)
            tables <- as.list(c("WQX_Stations" = "DM_WQX_Stations_MV", # this always has to be the first item
                                tables_list[data_type]))
            tables <- r_to_py(tables)
            print(glue('downloading {data_type} (2023 through present)'))
            python_get_data_2023_present(data_files_path,
                                         tables,
                                         ceden_server,
                                         ceden_id,
                                         ceden_pwd, 
                                         data_files_date)
            print(glue('finished downloading {data_type} (2023 through present)'))
            gc()
        }
        # rm('python_get_data_2023_present')
    },
    error = function(e) {
        error_message <- glue('Downloading data from 2023 to present (failed at: {data_type})')
        error_message_r <- capture.output(cat(as.character(e)))
        write(paste0(Sys.Date(), ': ', error_message, ' | ', error_message_r), file = 'upload_log.txt', append = TRUE)
        vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                              pattern = 'Ethernet adapter Ethernet 2|PANGP Virtual Ethernet Adapter Secure'))
        if (send_failure_email == TRUE) {
            if (vpn == FALSE) {
                fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
            } else {
                ## attempt to use gmailr if on the VPN
                tryCatch(
                    fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r),
                    error = function(e) {}
                )
            } 
        }
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

## download 2011 to 2022 ----
### NOTE: this only gets the 2011 - 2022 data, as an individual file for each year;
### bulk files with data across all years are created with the process that downloads data 
### up through 2010
tryCatch(
    {
        gc()
        ### get python function
        source_python(here('1_data_download', 
                           'CEDEN_DataRefresh_yearly_2011-to-2022_function.py')) 
        
        ### get data
        for (data_type in names(tables_list)) {
            Sys.sleep(1)
            tables <- as.list(c("WQX_Stations" = "DM_WQX_Stations_MV", # this always has to be the first item
                                tables_list[data_type]))
            tables <- r_to_py(tables)
            print(glue('downloading {data_type} (2011 through 2022)'))
            python_get_data_2011_2022(data_files_path,
                                      tables,
                                      ceden_server,
                                      ceden_id,
                                      ceden_pwd, 
                                      data_files_date)
            print(glue('finished downloading {data_type} (2011 through 2022)'))
            gc()
        }
        # rm('python_get_data_2011_2022')
    },
    error = function(e) {
        error_message <- glue('Downloading data from 2011 to 2022 (failed at: {data_type})')
        error_message_r <- capture.output(cat(as.character(e)))
        write(paste0(Sys.Date(), ': ', error_message, ' | ', error_message_r), file = 'upload_log.txt', append = TRUE)
        vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                              pattern = 'Ethernet adapter Ethernet 2|PANGP Virtual Ethernet Adapter Secure'))
        if (send_failure_email == TRUE) {
            if (vpn == FALSE) {
                fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
            } else {
                ## attempt to use gmailr if on the VPN
                tryCatch(
                    fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r),
                    error = function(e) {}
                )
            } 
        }
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

## download through 2010 ----
### NOTE: this gets the data up through 2010, as an individual file for each year,
### and also creates the bulk files with data across all years; it needs to be run
### last, as the processes that download more recent data will over-write some 
### of the bulk files
tryCatch(
    {
        gc()
        ### get python function
        source_python(here('1_data_download', 
                           'CEDEN_DataRefresh_yearly_through-2010_and-bulk-files_function.py'))
        
        ### get data
        for (data_type in names(tables_list)) {
            Sys.sleep(1)
            tables <- as.list(c("WQX_Stations" = "DM_WQX_Stations_MV", # this always has to be the first item
                                tables_list[data_type]))
            tables <- r_to_py(tables)
            print(glue('downloading {data_type} (through 2010)'))
            python_get_data_through_2010_and_bulk_files(data_files_path,
                                                        tables,
                                                        ceden_server,
                                                        ceden_id,
                                                        ceden_pwd, 
                                                        data_files_date)
            print(glue('finished downloading {data_type} (through 2010)'))
            gc()
        }
        # rm('python_get_data_through_2010_and_bulk_files')
    },
    error = function(e) {
        error_message <- glue('Downloading data through 2010 (failed at: {data_type})')
        error_message_r <- capture.output(cat(as.character(e)))
        write(paste0(Sys.Date(), ': ', error_message, ' | ', error_message_r), file = 'upload_log.txt', append = TRUE)
        vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                              pattern = 'Ethernet adapter Ethernet 2|PANGP Virtual Ethernet Adapter Secure'))
        if (send_failure_email == TRUE) {
            if (vpn == FALSE) {
                fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
            } else {
                ## attempt to use gmailr if on the VPN
                tryCatch(
                    fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r),
                    error = function(e) {}
                )
            } 
        }
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



# 4 - upload csv files ----------------------------------------------------

Sys.sleep(5)

options(timeout = 3600) # default is 60, units are seconds
tryCatch(
    {
        ### get python function
        #### install dependent python packages
        setwd(chunked_upload_directory)
        shell('pip install -r requirements.txt')
        setwd('..')
        #### get function
        source_python(python_upload_script)
        
        ### upload data
        for (upload_data_type in names(upload_files_list)) {
            for (upload_file in names(upload_files_list[[upload_data_type]])) {
                # for data types where all data is contained in a single file
                if (upload_data_type %in% c('BenthicData', 'ToxicityData', 'All_CEDEN_Sites')) {
                    print(glue('Uploading csv file(s) to data portal: {upload_data_type} | {upload_file}'))
                    ckanUploadFile(upload_files_list[[upload_data_type]][[upload_file]],
                                   paste0(data_files_path, upload_data_type, '_', data_files_date, '.csv'),
                                   portal_key)
                    print(glue('Finished uploading csv file(s) to data portal: {upload_data_type} | {upload_file}'))
                }
                
                # for data types where data is split into separate files by year
                if (upload_data_type %in% c('WaterChemistryData', 'HabitatData', 'TissueData')) {
                    print(glue('Uploading csv file(s) to data portal: {upload_data_type} | {upload_file}'))
                    ckanUploadFile(upload_files_list[[upload_data_type]][[upload_file]],
                                   paste0(data_files_path, upload_data_type, '_', upload_file, '_', data_files_date, '.csv'),
                                   portal_key)
                    print(glue('Finished uploading csv file(s) to data portal: {upload_data_type} | {upload_file}'))
                }
            }
        }
    },
    error = function(e) {
        error_message <- glue('Uploading csv file(s) to data portal (failed at: {upload_data_type} | {upload_file})')
        error_message_r <- capture.output(cat(as.character(e)))
        write(paste0(Sys.Date(), ': ', error_message, ' | ', error_message_r), file = 'upload_log.txt', append = TRUE)
        Sys.sleep(2)
        tryCatch(
            {
                vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                                      pattern = 'Ethernet adapter Ethernet 2|PANGP Virtual Ethernet Adapter Secure'))
                if (send_failure_email == TRUE) {
                    if (vpn == FALSE) {
                        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
                    } else {
                        ## attempt to use gmailr if on the VPN
                        tryCatch(
                            fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r),
                            error = function(e) {}
                        )
                    } 
                }
            },
            error = function(ee) {
                write_lines(x = glue('{Sys.time()} - CEDEN: {error_message} ---- R error message: {glue_collapse(error_message_r, sep = " | ")}'), 
                            file = 'C:\\Users\\daltare\\Desktop\\ERRORS.txt', 
                            append = TRUE)
            }
        )
        print(glue('Error: {error_message}'))
        Sys.sleep(2)
        stop(e)
    }
)



# 5 - upload zip files ----------------------------------------------------
## define zip files to upload ----
zip_resource_id_list <- list(
    'toxicity' = list(dataset_name = 'surface-water-toxicity-results',
                      dataset_id = 'ac8bf4c8-0675-4764-92f1-b67bdb187ba1',
                      data_file = glue('{data_files_path}ToxicityData_{data_files_date}.zip')),
    'benthic' = list(dataset_name = 'surface-water-benthic-macroinvertebrate-results',
                     dataset_id = '15349797-6cfc-4ef9-92ab-0ed36512de93',
                     data_file = glue('{data_files_path}BenthicData_{data_files_date}.zip')),
    'chemistry' = list(dataset_name = 'surface-water-chemistry-results',
                       dataset_id = '18dada05-3877-4520-906e-f16038d648b6',
                       data_file = glue('{data_files_path}WaterChemistryData_{data_files_date}.zip')),
    'habitat' = list(dataset_name = 'surface-water-habitat-results',
                     dataset_id = '24d9b91d-5f7e-471f-8720-849cceabe0ba',
                     data_file = glue('{data_files_path}HabitatData_{data_files_date}.zip')),
    'tissue' = list(dataset_name = 'surface-water-aquatic-organism-tissue-sample-results',
                    dataset_id = '4c38ae52-9fe2-4da0-9d0f-ea4b2203a41f',
                    data_file = glue('{data_files_path}TissueData_{data_files_date}.zip'))
)

## upload zip files ----
tryCatch(
    {
        print('Uploading zip files to data portal')
        source('1-1_ceden-zip-file-upload.R')
        print('Finished uploading zip files to data portal')
    },
    error = function(e) {
        error_message <- glue('Uploading zip files (error uploading: {ifelse(exists("data_file"), data_file, "NA")})')
        error_message_r <- capture.output(cat(as.character(e)))
        write(paste0(Sys.Date(), ': ', error_message, ' | ', error_message_r), file = 'upload_log.txt', append = TRUE)
        vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                              pattern = 'Ethernet adapter Ethernet 2|PANGP Virtual Ethernet Adapter Secure'))
        if (send_failure_email == TRUE) {
            if (vpn == FALSE) {
                fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
            } else {
                ## attempt to use gmailr if on the VPN
                tryCatch(
                    fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r),
                    error = function(e) {}
                )
            } 
        }
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



# 6 - create and upload parquet files -------------------------------------
## enter variables ----
data_dictionaries_path <- here('data_dictionaries', 
                               'data_dictionary_conversion')
parquet_file_save_location <- glue('{data_files_path}parquet_datasets')

## set package versions ----
### this allows you to use older versions of the arrow package
### version 5 seems to be unstable (fails unpredictably, causing R to become unresponsive)
### 2021-07-28 = arrow v4.0.1 (last release of v4)
### 2021-05-09 = arrow v4.0.0
### 2021-04-26 = arrow v3.0.0
### 2021-01-26 = arrow v2.0.0 # this should work
# checkpoint('2021-07-28') # , checkpoint_location = here())

### define parquet files to create & upload ----
parquet_resource_id_list <- list(
    'toxicity' = list(source_file_name = 'ToxicityData',
                      data_dictionary = 'toxicity\\CEDEN_Toxicity_Data_Dictionary.xlsx',
                      portal_dataset_name = 'surface-water-toxicity-results',
                      portal_dataset_id = 'a6c91662-d324-43c2-8166-a94dddd22982',
                      parquet_data_file = glue('ToxicityData_Parquet_{data_files_date}')),
    'benthic' = list(source_file_name = 'BenthicData',
                     data_dictionary = 'benthic\\CEDEN_Benthic_Data_Dictionary.xlsx',
                     portal_dataset_name = 'surface-water-benthic-macroinvertebrate-results',
                     portal_dataset_id = 'eb61f9a1-b1c6-4840-99c7-420a2c494a43',
                     parquet_data_file = glue('BenthicData_Parquet_{data_files_date}')),
    'chemistry' = list(source_file_name = 'WaterChemistryData',
                       data_dictionary = 'chemistry\\CEDEN_Chemistry_Data_Dictionary.xlsx',
                       portal_dataset_name = 'surface-water-chemistry-results',
                       portal_dataset_id = 'f4aa224d-4a59-403d-aad8-187955aa2e38',
                       parquet_data_file = glue('WaterChemistryData_Parquet_{data_files_date}')),
    'tissue' = list(source_file_name = 'TissueData',
                    data_dictionary = 'tissue\\CEDEN_Tissue_Data_Dictionary.xlsx',
                    portal_dataset_name = 'surface-water-aquatic-organism-tissue-sample-results',
                    portal_dataset_id = 'dea5e450-4196-4a8a-afbb-e5eb89119516',
                    parquet_data_file = glue('TissueData_Parquet_{data_files_date}')),
    'habitat' = list(source_file_name = 'HabitatData',
                     data_dictionary = 'habitat\\CEDEN_Habitat_Data_Dictionary.xlsx',
                     portal_dataset_name = 'surface-water-habitat-results',
                     portal_dataset_id = '0f83793d-1f12-4fee-87b2-45dcc1389f0c',
                     parquet_data_file = glue('HabitatData_Parquet_{data_files_date}'))
)

## create parquet files ----
tryCatch(
    {
        print('Creating parquet files')
        source('1-2_ceden-parquet-conversion.R')
        print('Finished creating parquet files')
    },
    error = function(e) {
        error_message <- glue('Creating parquet files (error creating: {ifelse(exists("file_name"), file_name, "NA")})')
        error_message_r <- capture.output(cat(as.character(e)))
        write(paste0(Sys.Date(), ': ', error_message, ' | ', error_message_r), file = 'upload_log.txt', append = TRUE)
        Sys.sleep(2)
        vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                              pattern = 'Ethernet adapter Ethernet 2|PANGP Virtual Ethernet Adapter Secure'))
        if (send_failure_email == TRUE) {
            if (vpn == FALSE) {
                fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
            } else {
                ## attempt to use gmailr if on the VPN
                tryCatch(
                    fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r),
                    error = function(e) {}
                )
            } 
        }
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

### revert back to using up-to-date packages (if needed - to be safe, this 
### can stay in the code regardless of whether or not checkpoint is used)
# uncheckpoint()
Sys.sleep(1) # pause to make sure reversion completes

## upload parquet files ----
tryCatch(
    {
        print('Uploading parquet files to data portal')
        source('1-3_ceden-parquet-file-upload.R')
        print('Finished uploading parquet files to data portal')
    },
    error = function(e) {
        error_message <- glue('Uploading parquet files (error uploading: {ifelse(exists("data_file"), data_file, "NA")})') 
        error_message_r <- capture.output(cat(as.character(e)))
        write(paste0(Sys.Date(), ': ', error_message, ' | ', error_message_r), file = 'upload_log.txt', append = TRUE)
        Sys.sleep(2)
        vpn <- any(str_detect(string = system("ipconfig /all", intern=TRUE), 
                              pattern = 'Ethernet adapter Ethernet 2|PANGP Virtual Ethernet Adapter Secure'))
        if (send_failure_email == TRUE) {
            if (vpn == FALSE) {
                fn_send_email(error_msg = error_message, error_msg_r = error_message_r)  
            } else {
                ## attempt to use gmailr if on the VPN
                tryCatch(
                    fn_email_gmailr(error_msg = error_message, error_msg_r = error_message_r),
                    error = function(e) {}
                )
            } 
        }
        print(glue('Error: {error_message}'))
        stop(e)
    }
)

print('CEDEN data portal update complete')
