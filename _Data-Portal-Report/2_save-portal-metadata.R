# (1) get data portal report and (2) save report files on sharepoint / teams



# load packages -----------------------------------------------------------
library(tidyverse)
library(writexl)
library(lubridate)



# user inputs -------------------------------------------------------------
## define where to save the results of the report
paths_output <- c('C:\\Users\\daltare\\Water Boards\\Data Integration & Analysis - CalEPA Open Data\\Data-Portal-Report',
                  'C:\\Users\\daltare\\Water Boards\\OIMA Data Team - Open Data\\Data-Portal-Report')

## enter the email address to send warning emails from
### NOTE - if sending from a personal email address, you'll have to update the credentials -- see below
email_from <- 'daltare.swrcb@gmail.com' # 'david.altare@waterboards.ca.gov' # "gisscripts-noreply@waterboards.ca.gov"

## create credentials file (only need to do this once) 
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

## enter the email address (or addresses) to send warning emails to
email_to <- 'david.altare@waterboards.ca.gov' 
# email_to <- c('david.altare@waterboards.ca.gov', 'waterdata@waterboards.ca.gov') # for GIS scripting server



# setup automated email -----------------------------------------------

## create email function ----
fn_send_email <- function(error_msg, error_msg_r) {
    
    ### create components ----
    #### date/time ----
    date_time <- add_readable_time()
    
    #### body ----
    body <- glue(
        "Hi,
        
There was an error creating the Data Portal Report on {Sys.Date()}.

------
                
The process failed at this step: *{error_msg}*

Here's the error message from R: *{glue_collapse(error_msg_r, sep = ' | ')}*"                
    )
    
    #### footer ----
    footer <- glue("Email sent on {date_time}.")
    
    #### subject ----
    subject <- "Data Portal Report Error"
    
    ### create email ----
    email <- compose_email(
        body = md(body),
        footer = md(footer)
    )
    
    
    ### send email via blastula (using credentials file) ----
    email %>%
        smtp_send(
            # to = c("david.altare@waterboards.ca.gov", "waterdata@waterboards.ca.gov"),
            to = email_to,
            from = email_from,
            subject = subject,
            credentials = creds_file(credentials_file)
            # credentials = creds_key("outlook_key")
        )
    
    ### send email via sendmailR (for use on GIS scripting server) ----
    # sendmail(email_from,email_to,subject,body,control=list(smtpServer= ""))
    
    print('sent automated email')
}


# get data ----------------------------------------------------------------
tryCatch(
    {
        source('1_get-portal-metadata.R')
        
    },
    error = function(e) {
        error_message <- 'getting portal metadata'
        error_message_r <- capture.output(cat(as.character(e)))
        fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
        print(glue('Error: {error_message}'))
        stop(e)
    }
)



# write output files ------------------------------------------------------
for (output_path in paths_output) {
    
    # output_path <- paths_output[1] # for testing
    
    ## delete old versions ----
    # NOTE: Only needed if using date in filename
    # files_existing <- list.files(output_path)
    # files_remove <- files_existing[str_detect(string = files_existing, 
    #                                           pattern = 'DataPortalReport_[0-9]+-[0-9]+-[0-9]+.xlsx')]
    # files_remove <- c(files_remove, 
    #                   files_existing[str_detect(string = files_existing, 
    #                                           pattern = 'DataPortalReport-[Datasets|Resources]+_[0-9]+-[0-9]+-[0-9]+.csv')]
    # )
    # unlink(file.path(output_path, files_remove))
    
    tryCatch(
        {
            ## combined datasets & resources (excel only) ----
            write_xlsx(x = list(datasets = df_datasets_format,
                                resources = df_resources_format), 
                       path = paste0(output_path, '\\',
                                     'DataPortalReport', 
                                     # '_', Sys.Date() %>% with_tz(tzone = 'America/Los_Angeles'), 
                                     '.xlsx'))
            
            ## datasets (csv) ----
            # write_excel_csv(x = df_datasets_format, 
            #                 file = paste0(output_path, '\\',
            #                               'DataPortalReport-Datasets_', 
            #                               Sys.Date(), '.csv'))
            
            
            ## resources (csv) ----
            # write_excel_csv(x = df_resources_format, 
            #                 file = paste0(output_path, '\\',
            #                               'DataPortalReport-Resources_', 
            #                               Sys.Date(), '.csv'))
            
        },
        error = function(e) {
            error_message <- 'getting portal metadata'
            error_message_r <- capture.output(cat(as.character(e)))
            fn_send_email(error_msg = error_message, error_msg_r = error_message_r)
            print(glue('Error: {error_message}'))
            stop(e)
        }
    )
    
}

print('Finished data portal report creation')
