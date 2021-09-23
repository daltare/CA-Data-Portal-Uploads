library(blastula)


# set up credentials ------------------------------------------------------
## NOTE: when running the function below you'll be prompted to enter a SMTP server password --
## just enter the password used for your windows log-in there (i.e. the same password used to log 
## in to the computer when starting it up)

## credentials file ----
### outlook credentials ----
# create_smtp_creds_file(file = 'outlook_creds', 
#                        user = 'david.altare@waterboards.ca.gov',
#                        provider = 'outlook'
#                        )

### gmail credentials ----
### !!! NOTE - for gmail, you also have to enable 'less secure apps'  within your 
### gmail account settings - see: https://github.com/rstudio/blastula/issues/228
# create_smtp_creds_file(file = 'gmail_creds', 
#                        user = 'daltare.work@gmail.com',
#                        provider = 'gmail'
#                        )

## credentials key ----
### Note: the 'keyring' package has to be installed for this to work
# create_smtp_creds_key(id = 'outlook_key',
#                       user = 'david.altare@waterboards.ca.gov',
#                       provider = 'outlook')



# Example: create and send an email ---------------------------------------

## Step 1 - define input strings / images ----
### Get a nicely formatted date/time string
date_time <- add_readable_time()

### Create an image string using an on-disk image file
img_file_path <-
  system.file(
    "img", "pexels-photo-267151.jpeg",
    package = "blastula"
  )

img_string <- add_image(file = img_file_path)


## Step 2 - create email ----
email <-
    compose_email(
        body = md(glue::glue(
            "Hello,

This is a *great* picture I found when looking
for sun + cloud photos:

{img_string}
")),
        footer = md(glue::glue("Email sent on {date_time}."))
    )


## Step 3 - preview the email ----
email


## Step 4 - send email by SMTP using credentials file ----
### send from outlook ----
email %>%
  smtp_send(
    to = "david.altare@waterboards.ca.gov",
    from = "david.altare@waterboards.ca.gov",
    subject = "Testing the `smtp_send()` function",
    credentials = creds_file("outlook_creds"),
    verbose = TRUE
    # credentials = creds_key("outlook_key")
  )


### send from gmail ----
email %>%
  smtp_send(
    to = "david.altare@waterboards.ca.gov",
    from = "daltare.work@gmail.com",
    subject = "Testing the `smtp_send()` function",
    credentials = creds_file("gmail_creds"),
    verbose = TRUE
    # credentials = creds_key("outlook_key")
  )
