# load libraries ----
library(tidyverse)
library(tictoc)
library(janitor)
library(lubridate)


# data source
esmr_url <- 'https://intapps.waterboards.ca.gov/downloadFile/faces/flatFilesCiwqs.xhtml?fileName=esmr_analytical_export.txt'


# download data (most recent version) ----
{
    opt_timeout <- getOption('timeout')
    options(timeout = 3600)
    temp_file <- tempfile()
    tic()
    download.file(url = esmr_url, 
                  # destfile = paste0('C:\\David\\_CA_data_portal\\CIWQS\\', 
                  #                   'esmr_analytical_export_', 
                  #                   Sys.Date(), 
                  #                   '.txt'),
                  destfile = temp_file,
                  method = 'curl')
    options(timeout = opt_timeout)
    t <- toc()
}
time_download <- (t$toc - t$tic) / 60 # minutes


# read data ----
{
    tic()
    df_esmr <- read_tsv(file = temp_file,
                        col_types = cols(.default = col_character()),
                        quote = '') %>%
        clean_names() %>%
        select(-matches('^x[123456789]'))
    t2 <- toc()
}
time_read <- (t2$toc - t2$tic) / 60 # minutes


# format data ----
# glimpse(df_esmr)

## format dates ----
df_esmr <- df_esmr %>% 
    mutate(sampling_date_rev = mdy(sampling_date),
           sampling_year = year(sampling_date_rev),
           analysis_date_rev = mdy(analysis_date),
           analysis_year = year(analysis_date_rev))
## check years
# View(df_esmr %>% count(sampling_year))
glimpse(df_esmr)

## check incorrect years
# df_esmr %>% filter(sampling_year < 1899) %>% pull(sampling_date)
# df_esmr %>% filter(sampling_year == 1931) %>% pull(sampling_date)


# filter by year ----
for (i_year in 2016:2021) {
    write_csv(x = df_esmr %>% 
                  filter(sampling_year == i_year) %>% 
                  mutate(analysis_date = analysis_date_rev,
                         sampling_date = sampling_date_rev) %>% 
                  select(-analysis_date_rev, -analysis_year, -sampling_date_rev, -sampling_year), 
              file = paste0('C:\\David\\_CA_data_portal\\Surface-Water-Datasets\\esmr\\', 
                            'esmr_analytical_export_',
                            'year-', i_year,
                            '_', Sys.Date(),
                            '.csv'))
}
    