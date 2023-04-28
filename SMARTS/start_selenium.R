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

## conflicts ----
library(conflicted)
conflicts_prefer(magrittr::extract)



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
selenium(
    check = TRUE,
    retcommand = TRUE,
    port = port_use
)
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