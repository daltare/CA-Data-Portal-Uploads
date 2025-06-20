# Set up selenium


# load packages -----------------------------------------------------------
library(tidyverse)
library(RSelenium)
library(wdman)
library(methods) # seems this needs to be called explicitly to avoid an error
library(pingr)
library(binman)
library(here)
library(magrittr)
library(rvest)
library(httr)
library(glue)

## conflicts ----
library(conflicted)
conflicts_prefer(dplyr::filter,
                 magrittr::extract,
                 utils::unzip)



# start selenium server ---------------------------------------------------
print('Setting up Selenium server')

## set times for Sys.sleep() arguments
sleep_time <- 0.5

## define chrome browser options for the Selenium session ----
eCaps <- list( 
    chromeOptions = 
        list(prefs = list(
            "profile.default_content_settings.popups" = 0L,
            "download.prompt_for_download" = FALSE,
            "download.default_directory" = gsub(pattern = '/', replacement = '\\\\', x = download_dir)
        )
        )
)

## check for open port ----
for (port_check in 4567L:4577L) {
    port_test <- ping_port(destination = 'localhost', port = port_check)
    # print(all(is.na(port_test)))
    if (all(is.na(port_test)) == TRUE) {
        port_use <- port_check
        break
    }
}

## get drivers ----
### note - this may not work if on the waterboard VPN, so only run this command 
### if not on the VPN
# vpn <- any(
#     str_detect(string = system("ipconfig /all", 
#                                intern = TRUE), 
#                pattern = 'ca.epa.local')
#     )
# if (vpn == FALSE) {
tryCatch(
    {
        selenium(
            check = TRUE,
            retcommand = TRUE,
            port = port_use,
            phantomver = NULL,
            iedrver = NULL,
            geckover = NULL
            )    
    },
    error = function(e) {
        error_message <- capture.output(cat(as.character(e)))
        print(glue('{error_message}'))
    }
)
 
# }

### get chrome driver directly from google ---- 
#### (https://googlechromelabs.github.io/chrome-for-testing/#stable)
#### see: https://support.google.com/chrome/thread/230521170/requires-version-116-of-the-google-chrome-driver%EF%BC%8Cplease?hl=en
#### for web scraping example, see: https://dcl-wrangle.stanford.edu/rvest.html
driver_url <- 'https://googlechromelabs.github.io/chrome-for-testing/#stable'

#### read summary table of drivers from google website
# css_selector_summary <- 'body > div > table'
css_selector_summary <- '.summary'
driver_table_summary <- driver_url %>% 
    read_html() %>% 
    html_element(css = css_selector_summary) %>% 
    html_table()

#### read 'Stable' table of drivers from google website - to get driver URL
# css_selector_stable <- 'body > section > div > table'
css_selector_stable <- '#stable'
driver_table_stable <- driver_url %>% 
    read_html() %>% 
    html_element(css = css_selector_stable) %>%
    html_table()
driver_download_url <- driver_table_stable %>% 
    filter(Binary == 'chromedriver', 
           Platform == 'win32', 
           `HTTP status` == 200) %>% 
    slice(1) %>% 
    pull(URL)

#### get current stable driver version number from table
driver_version_number <- driver_table_summary %>% 
    filter(Channel == 'Stable') %>% 
    pull(Version)

#### define local directory for driver 
driver_dir <- file.path(app_dir("chromedriver", FALSE), 
                        'win32', 
                        driver_version_number)

#### if driver not already saved locally, download and unzip
redownload_driver <- FALSE
if (dir.exists(driver_dir))  {
    if (!"chromedriver.exe" %in% list.files(driver_dir)) {
        redownload_driver == TRUE
    }
}
if (!dir.exists(driver_dir) | redownload_driver == TRUE) {
    # create directory
    dir.create(driver_dir)
    
    zip_name <- basename(driver_download_url)
    zip_folder <- str_remove(zip_name, '.zip')
    
    # download zip file to new directory
    driver_download <- GET(url = driver_download_url, 
                           write_disk(file.path(driver_dir, 
                                                zip_name),
                                      overwrite = TRUE))
    
    if(driver_download$status_code != 200) {
        stop('Chrome driver not downloaded successfully')
    }
    
    # unzip the chromedriver.exe file
    if (!file.exists(file.path(driver_dir, 'chromedriver.exe'))) {
        unzip(zipfile = file.path(driver_dir, 
                                  zip_name), 
              files = file.path(zip_folder, 'chromedriver.exe'), 
              junkpaths = TRUE,
              exdir = driver_dir) 
    }  
}

Sys.sleep(sleep_time)

### get current version of chrome browser ----
chrome_browser_version <-
    system2(command = "wmic",
            args = 'datafile where name="C:\\\\Program Files (x86)\\\\Google\\\\Chrome\\\\Application\\\\chrome.exe" get Version /value',
            stdout = TRUE,
            stderr = TRUE) %>%
    str_extract(pattern = "(?<=Version=)(\\d+\\.){3}")
if (sum(!is.na(chrome_browser_version)) == 0) {
    chrome_browser_version <-
        system2(command = "wmic",
                args = 'datafile where name="C:\\\\Program Files\\\\Google\\\\Chrome\\\\Application\\\\chrome.exe" get Version /value',
                stdout = TRUE,
                stderr = TRUE) %>%
        str_extract(pattern = "(?<=Version=)(\\d+\\.){3}")
}

### get available chrome drivers ----
chrome_driver_versions <- list_versions("chromedriver")

### match driver / version ----
chrome_driver_current <- chrome_browser_version %>%
    extract(!is.na(.)) %>%
    str_replace_all(pattern = "\\.",
                    replacement = "\\\\.") %>%
    paste0("^",  .) %>%
    str_subset(string = last(chrome_driver_versions)) %>%
    as.numeric_version() %>%
    max() %>%
    as.character()

### if no matching driver / version, use most recent driver ----
if(is_empty(chrome_driver_current)) {
    chrome_driver_current <- tibble(version = last(chrome_driver_versions)) %>% 
        separate_wider_delim(cols = version, 
                             delim = '.', 
                             names_sep = '', 
                             cols_remove = FALSE) %>% 
        rename(version = versionversion) %>% 
        mutate(across(num_range('version', 1:4), as.numeric)) %>% 
        arrange(desc(version1), desc(version2), desc(version3), desc(version4)) %>% 
        slice(1) %>% 
        pull(version)
}

## re-check for open port ----
for (port_check in 4567L:4577L) {
    port_test <- ping_port(destination = 'localhost', port = port_check)
    # print(all(is.na(port_test)))
    if (all(is.na(port_test)) == TRUE) {
        port_use <- port_check
        break
    }
}

## remove the 'LICENSE.chromedriver' file (if it exists)
chrome_driver_dir <- paste0(app_dir("chromedriver", FALSE), 
                            '/win32/',
                            chrome_driver_current)
if ('LICENSE.chromedriver' %in% list.files(chrome_driver_dir)) {
    file.remove(
        paste0(chrome_driver_dir, '/', 'LICENSE.chromedriver')
    )
}

## set up selenium with the current chrome version ----
selCommand <- wdman::selenium(
    jvmargs = c("-Dwebdriver.chrome.verboseLogging=true"),
    check = FALSE,
    retcommand = TRUE,
    chromever = chrome_driver_current,
    port = port_use
)

### write selenium specifications to batch file ----
# writeLines(selCommand, 
#            here('Start_Server.bat'))

Sys.sleep(sleep_time) # wait a few seconds

### start server ----
# shell.exec(here('Start_Server.bat'))
shell(cmd = selCommand, 
      wait = FALSE)

Sys.sleep(sleep_time) # wait a few seconds

### open connection ----
remDr <- remoteDriver(port = port_use, # 4567L, 
                      browserName = "chrome", 
                      extraCapabilities = eCaps)
Sys.sleep(sleep_time) # wait a few seconds
remDr$open() 
