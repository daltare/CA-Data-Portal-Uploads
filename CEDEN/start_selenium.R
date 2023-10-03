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

## conflicts ----
library(conflicted)
conflicts_prefer(magrittr::extract)



# start selenium server ---------------------------------------------------
print('Setting up Selenium server')

## define chrome browser options for the Selenium session ----
eCaps <- list( 
    chromeOptions = 
        list(prefs = list(
            "profile.default_content_settings.popups" = 0L,
            "download.prompt_for_download" = FALSE,
            "download.default_directory" = gsub(pattern = '/', replacement = '\\\\', x = getwd()) # download.dir
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
vpn <- any(
    str_detect(string = system("ipconfig /all", 
                               intern = TRUE), 
               pattern = 'ca.epa.local')
    )
if (vpn == FALSE) {
    selenium(
        check = TRUE,
        retcommand = TRUE,
        port = port_use
    )  
}

### get chrome driver directly from google ---- 
#### (https://googlechromelabs.github.io/chrome-for-testing/#stable)
#### see: https://support.google.com/chrome/thread/230521170/requires-version-116-of-the-google-chrome-driver%EF%BC%8Cplease?hl=en
#### for web scraping example, see: https://dcl-wrangle.stanford.edu/rvest.html
driver_url <- 'https://googlechromelabs.github.io/chrome-for-testing/#stable'
css_selector <- 'body > div > table'

#### read table of drivers from google website
driver_table <- driver_url %>% 
    read_html() %>% 
    html_element(css = css_selector) %>% 
    html_table()

#### get current stable driver version number from table
driver_version_number <- driver_table %>% 
    filter(Channel == 'Stable') %>% 
    pull(Version)

#### define local directory for driver 
driver_dir <- file.path(app_dir("chromedriver", FALSE), 
                        'win32', 
                        driver_version_number)

#### if driver not already saved locally, download and unzip
if (!dir.exists(driver_dir)) {
    # create directory
    dir.create(driver_dir)
    
    #### construct link to new driver zip file
    driver_zip_file <- paste0('https://edgedl.me.gvt1.com/edgedl/chrome/chrome-for-testing/',
                              driver_version_number,
                              '/win32/chromedriver-win32.zip')
    
    # download zip file to new directory
    GET(url = driver_zip_file, 
        write_disk(file.path(driver_dir, 
                             'chromedriver-win32.zip'),
                   overwrite = TRUE))
    
    # unzip the chromedriver.exe file 
    unzip(zipfile = file.path(driver_dir, 
                              'chromedriver-win32.zip'), 
          files = 'chromedriver-win32/chromedriver.exe', 
          junkpaths = TRUE,
          exdir = driver_dir)    
}

Sys.sleep(1)

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
writeLines(selCommand, 
           here('Start_Server.bat'))
Sys.sleep(1) # wait a few seconds

### start server ----
shell.exec(here('Start_Server.bat'))

Sys.sleep(1) # wait a few seconds

### open connection ----
remDr <- remoteDriver(port = port_use, # 4567L, 
                      browserName = "chrome", 
                      extraCapabilities = eCaps)
Sys.sleep(1) # wait a few seconds
remDr$open() 

