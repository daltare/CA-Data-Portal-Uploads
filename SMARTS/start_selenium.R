# Set up selenium

# load packages
library(tidyverse)
library(RSelenium)
library(wdman)
library(methods) # it seems that this needs to be called explicitly to avoid an error for some reason
library(pingr)
library(binman)
library(here)




print('Setting up Selenium server')
## define chrome browser options for the Selenium session ----
eCaps <- list( 
    chromeOptions = 
        list(prefs = list(
            "profile.default_content_settings.popups" = 0L,
            "download.prompt_for_download" = FALSE,
            "download.default_directory" = gsub(pattern = '/', replacement = '\\\\', x = download_dir) # "download.default_directory" = gsub(pattern = '/', replacement = '\\\\', x = getwd())
        )
        )
)

## Open the connection ----
### setup ----
#### OLD METHOD (for some reason it doesn't work when running as an automated task with the task scheduler, but does work when just running from a normal RStudio session) 
# rsD <- rsDriver(port = 4444L, browser = 'chrome', extraCapabilities = eCaps) #, chromever = "75.0.3770.90")
# remDr <- rsD$client
# probably don't need these lines anymore:
# remDr <- remoteDriver(browserName="chrome", port = 4444L, extraCapabilities = eCaps)
# remDr$open()


#### NEW METHOD (works when running as an automated task)
#### (see: https://github.com/ropensci/RSelenium/issues/221)

# selenium(jvmargs =
#              c("-Dwebdriver.chrome.verboseLogging=true"),
#          retcommand = TRUE)


#### check for open port ----
for (port_check in 4567L:4577L) {
    port_test <- ping_port(destination = 'localhost', port = port_check)
    # print(all(is.na(port_test)))
    if (all(is.na(port_test)) == TRUE) {
        port_use <- port_check
        break
    }
}

#### get drivers ----
selenium(
    check = TRUE,
    retcommand = TRUE,
    port = port_use
)
Sys.sleep(5)

#### get current version of chrome browser ----
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

#### get available chrome drivers ----
chrome_driver_versions <- list_versions("chromedriver")

#### match driver / version ----
chrome_driver_current <- chrome_browser_version %>%
    magrittr::extract(!is.na(.)) %>%
    str_replace_all(pattern = "\\.",
                    replacement = "\\\\.") %>%
    paste0("^",  .) %>%
    str_subset(string = last(chrome_driver_versions)) %>%
    as.numeric_version() %>%
    max() %>%
    as.character()

#### re-check for open port ----
for (port_check in 4567L:4577L) {
    port_test <- ping_port(destination = 'localhost', port = port_check)
    # print(all(is.na(port_test)))
    if (all(is.na(port_test)) == TRUE) {
        port_use <- port_check
        break
    }
}

#### remove the 'LICENSE.chromedriver' file (if it exists)
chrome_driver_dir <- paste0(app_dir("chromedriver", FALSE), 
                            '/win32/',
                            chrome_driver_current)
# list.files(chrome_driver_dir)
if ('LICENSE.chromedriver' %in% list.files(chrome_driver_dir)) {
    file.remove(
        paste0(chrome_driver_dir, '/', 'LICENSE.chromedriver')
    )
}

#### set up selenium with the current chrome version ----
selCommand <- wdman::selenium(
    jvmargs = c("-Dwebdriver.chrome.verboseLogging=true"),
    check = FALSE,
    retcommand = TRUE,
    chromever = chrome_driver_current,
    port = port_use
)

#### OLD - No longer needed
# cat(selCommand) # view / print to console #Run this, and paste the output into a terminal (cmd) window

#### write selenium specifications to batch file ----
writeLines(selCommand, 
           here('Start_Server.bat'))
Sys.sleep(5) #### wait a few seconds

#### start server ----
shell.exec(here('Start_Server.bat'))

Sys.sleep(10) #### wait a few seconds

# This command starts the server, by entering the output from the line above into a command window
# shell.exec(file = 'C:/David/Stormwater/_SMARTS_Data_Download_Automation/Start_Server.bat')
# NOTE: There can be a mismatch between the Chrome browser version and the Chrome driver version - if so, it may 
# be necessary to manually edit the output of the steps above to point to the correct version of the 
# driver (at: C:\Users\daltare\AppData\Local\binman\binman_chromedriver\win32) - also see: https://stackoverflow.com/questions/55201226/session-not-created-this-version-of-chromedriver-only-supports-chrome-version-7

### open connection ----
remDr <- remoteDriver(port = port_use, # 4567L, 
                      browserName = "chrome", 
                      extraCapabilities = eCaps)
Sys.sleep(10) #### wait a few seconds
remDr$open() 