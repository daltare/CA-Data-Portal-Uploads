# data portal report application


# load packages -----------------------------------------------------------
library(shiny)
library(shinydashboard)
# library(ckanr)
library(dplyr)
library(readr)
library(writexl)
library(lubridate)
# library(here)
# library(icons)
library(DT)
library(ggplot2)
library(forcats)
library(plotly)
library(scales)
library(stringr)


# get data ----------------------------------------------------------------
source('1_get-portal-metadata.R')



# create app --------------------------------------------------------------#

# define UI 
ui <- dashboardPage(
    
    ## header ----
    dashboardHeader(title = 'Open Data Portal Report ‒ CA State Water Resources Control Board', 
                    titleWidth = 650),
    
    ## sidebar ----
    dashboardSidebar(#width = 250,
        # define button style (background color and font color)
        # tags$style(".buttonstyle{background-color:#f2f2f2;} .buttonstyle{color: black;}"),
        tags$style(".buttonstyle{background-color:grey;} .buttonstyle{color: blue;}"),
        sidebarMenu(
            menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
            menuItem("Datasets", tabName = "datasets", icon = icon('table')), # , lib = 'font-awesome'
            menuItem("Resources", tabName = "resources", icon = icon("file")),
            ## download button
            hr(style = "border-color: grey;"), # margin-top: 0px; margin-bottom: 0px;"),
            h4('Download All Dataset &', tags$br(), 'Resource Metadata:'),
            HTML('&emsp;'), 
            downloadButton(outputId = 'download_summary', 
                           label = 'Download (Excel File)', 
                           class = 'btn-primary'
                           # class = 'buttonstyle'
            )
            #HTML('&emsp;')
        )
    ),
    
    ## body ----
    dashboardBody(
        
        tabItems(
            
            ### dashboard tab ----
            tabItem(tabName = 'dashboard',
                    tags$head(tags$style(HTML('.info-box {min-height: 70px;} .info-box-icon {height: 70px; line-height: 70px;} .info-box-content {padding-top: 0px; padding-bottom: 0px;}'))),
                    fluidRow(
                        # infoBox(title = 'Datasets', value = nrow(df_datasets_format), icon = icon('table'), fill = TRUE),
                        # number of datasets
                        # valueBox(value = nrow(df_datasets_format), 
                        #          subtitle =  "Datasets", 
                        #          icon = icon("table"), 
                        #          href = 'https://data.ca.gov/organization/california-state-water-resources-control-board'),
                        
                        infoBox(value = nrow(df_datasets_format), 
                                title =  "Datasets", 
                                icon = icon("table"), 
                                fill = TRUE,
                                href = 'https://data.ca.gov/organization/california-state-water-resources-control-board'),
                        
                        
                        # number of resources
                        # valueBox(value = nrow(df_resources_format), 
                        #          subtitle = 'Resources', 
                        #          icon = icon('file'))#,
                        
                        # number of resources
                        infoBox(value = nrow(df_resources_format), 
                                title = 'Resources', 
                                icon = icon('file'), fill = TRUE),
                    ), 
                    
                    # ## Download Data Button ----
                    # fluidRow(
                    #     # h5('Download All Dataset & Resource Metadata:'),
                    #     div(style = "display:inline-block;vertical-align:top;",
                    #         HTML('&emsp;'), h3('Download All Dataset & Resource Metadata: ', style = 'display:inline'), HTML('&emsp;'),  
                    #         downloadButton('download_summary', 'Download'), HTML('&emsp;')
                    #     ),
                    #     hr(style="border-color: black;")
                    # ),
                    # fluidRow(
                    #     tags$hr(style="border-color: black;")
                    # ),
                    # fluidRow(
                    #     hr(style = "border-color: grey; margin-top: 0px; margin-bottom: 0px;")
                    # ),
                    fluidRow(
                        # tags$br(),
                        h3('Resources Summary ‒ File Types:')
                    ),
                    fluidRow(
                        infoBox(value = nrow(df_resources_format %>% filter(resource_type == 'CSV')), 
                                title = 'CSV Files', 
                                icon = icon('file-csv')),
                        infoBox(value = nrow(df_resources_format %>% filter(resource_type == 'XLSX')), 
                                title = 'Excel Files', 
                                icon = icon('file-excel')),
                        infoBox(value = nrow(df_resources_format %>% filter(resource_type == 'ZIP')), 
                                title = 'Zip Files', 
                                icon = icon('file-export'))
                    ),
                    fluidRow(
                        infoBox(value = nrow(df_resources_format %>% filter(resource_type == 'PDF')), 
                                title = 'PDF Files', 
                                icon = icon('file-pdf')),
                        infoBox(value = nrow(df_resources_format %>% filter(resource_type %in% c('DOCX', 'DOC'))), 
                                title = 'Word Files', 
                                icon = icon('file-word')),
                        infoBox(value = nrow(df_resources_format %>% 
                                                 filter(!resource_type %in% c('CSV', 'XLSX', 'ZIP',
                                                                              'PDF', 'DOCX', 'DOC'))), 
                                title = 'Other File Types', 
                                icon = icon('file'))
                    ),
                    # fluidRow(
                    #     hr(style = "border-color: grey; margin-top: 0px; margin-bottom: 0px;")
                    # ),
                    fluidRow(
                        # tags$br(),
                        h3('CSV Resources Summary ‒ Date Updated:')
                    ),
                    # fluidRow(
                    #     infoBox(value = nrow(df_resources_format %>% filter(resource_type == 'CSV') %>% 
                    #                              filter(resource_last_update_within == '1 Day')), 
                    #             title = '1 Day', icon = icon('file-csv'), width = 3),
                    #     infoBox(value = nrow(df_resources_format %>% filter(resource_type == 'CSV') %>% 
                    #                              filter(resource_last_update_within == '2 Days to 1 Week')), 
                    #             title = '2 Days to 1 Week', icon = icon('file-csv'), width = 3),
                    #     infoBox(value = nrow(df_resources_format %>% filter(resource_type == 'CSV') %>% 
                    #                              filter(resource_last_update_within == '1 Week to 1 Month')), 
                    #             title = '1 Week to 1 Mon.', icon = icon('file-csv'), width = 3),
                    #     infoBox(value = nrow(df_resources_format %>% filter(resource_type == 'CSV') %>% 
                    #                              filter(resource_last_update_within == '1 to 3 Months')), 
                    #             title = '1 to 3 Months', icon = icon('file-csv'), width = 3),
                    #     infoBox(value = nrow(df_resources_format %>% filter(resource_type == 'CSV') %>% 
                    #                              filter(resource_last_update_within == '3 to 6 Months')), 
                    #             title = '3 to 6 Months', icon = icon('file-csv'), width = 3),
                    #     infoBox(value = nrow(df_resources_format %>% filter(resource_type == 'CSV') %>% 
                    #                              filter(resource_last_update_within == '6 Months to 1 Year')), 
                    #             title = '6 Mon. to 1 Year', icon = icon('file-csv'), width = 3),
                    #     infoBox(value = nrow(df_resources_format %>% filter(resource_type == 'CSV') %>% 
                    #                              filter(resource_last_update_within == '> 1 Year')), 
                    #             title = '> 1 Year', icon = icon('file-csv'), width = 3)
                    # ), 
                    fluidRow(
                        # plotOutput(outputId = 'resources_plot', height = 300, width = 900),
                        plotlyOutput(outputId = 'resources_plotly', height = 300, width = 1000)
                    )
            ),
            
            ### datasets tab ----
            tabItem(
                tabName = 'datasets',
                h2('Datasets'),
                DTOutput('datasets_table')
            ),
            
            ### resources tab ----
            tabItem(tabName = 'resources',
                    h2('Resources'),
                    DTOutput('resources_table')
            )
        )
    )
)



# Define server logic -----------------------------------------------------
server <- function(input, output) {
    
    ## download all data button
    output$download_summary <- downloadHandler(
        filename = function () {
            paste0('DataPortalReport', 
                   # '_', Sys.Date() %>% with_tz(tzone = 'America/Los_Angeles'), 
                   '.xlsx')
        }, 
        content = function(file) {
            write_xlsx(x = list(datasets = df_datasets_format,
                                resources = df_resources_format),
                       path = file
            )
        }#,
        # contentType = 'text/csv'
    )
    
    ## csv resources plot ----
    
    ### define a custom function
    str_pad_custom <- function(labels){
        new_labels <- stringr::str_pad(labels, 5, "right")
        return(new_labels)
    }
    
    ### ggplot ----
    output$resources_plot <- renderPlot( 
        ggplot(df_resources_format %>% 
                   filter(resource_type == 'CSV') %>% 
                   # mutate(resource_last_update_within = str_pad(resource_last_update_within, 15, 'right')) %>% # increases spacing of legend
                   mutate(resource_last_update_within = fct_reorder(resource_last_update_within, 
                                                                    as.Date(resource_last_update)))) +
            geom_bar(mapping = aes(y = resource_last_update_within,
                                   # y = resource_type, 
                                   fill = resource_last_update_within)) +
            theme_minimal() +
            # xlab('Number of CSV Resources') +
            scale_x_continuous(name = 'Number of CSV Resources', 
                               # labels = str_pad_custom,
                               # breaks = breaks_pretty(10)
                               breaks = breaks_width(20)
            ) + 
            theme(#legend.position = 'bottom', 
                legend.position = 'right',
                legend.title = element_blank(), 
                legend.spacing.x = unit(0.5, 'cm'),
                # legend.key.size = unit(0.2, "cm"),
                # axis.title.x = element_blank(), 
                axis.title.y = element_blank(), 
                axis.text.y = element_blank(),
                axis.ticks.y = element_blank(),
                rect = element_rect(fill = "transparent")) +
            guides(fill = guide_legend(reverse = TRUE, # legend elements in proper order
                                       # nrow = 1,
                                       NULL)) + # all legend elements on one row
            NULL, 
        bg = 'transparent'
    )
    
    reverse_legend_labels <- function(plotly_plot) {
        n_labels <- length(plotly_plot$x$data)
        plotly_plot$x$data[1:n_labels] <- plotly_plot$x$data[n_labels:1]
        plotly_plot
    }
    
    ### plotly ----
    output$resources_plotly <- renderPlotly(
        ggplotly(
            ggplot(data = df_resources_format %>%
                       filter(resource_type == 'CSV') %>%
                       mutate(resource_last_update_within = fct_reorder(resource_last_update_within,
                                                                        as.Date(resource_last_update)))) +
                geom_bar(mapping = aes(#y = resource_type,
                    y = resource_last_update_within,
                    fill = resource_last_update_within)) +
                theme_minimal() +
                # xlab('Number of CSV Resources') +
                scale_x_continuous(name = 'Number of CSV Resources',
                                   # breaks = breaks_pretty(10)
                                   breaks = breaks_width(20)
                ) +
                theme(#legend.position = 'bottom',
                    legend.position = 'none',
                    legend.title = element_blank(),
                    # axis.title.x = element_blank(),
                    axis.title.y = element_blank(),
                    # axis.text.y = element_blank(),
                    # axis.ticks.y = element_blank(),
                    rect = element_rect(fill = "transparent")) +
                guides(fill = guide_legend(reverse = TRUE)) +
                NULL, 
            tooltip = c('x') #, 'fill')
        ) %>% 
            layout(paper_bgcolor='#ECF0F5',
                   plot_bgcolor='#ECF0F5',
                   # legend = list(title=list(text=NULL)),
                   NULL
            ) %>% 
            # reverse_legend_labels() %>% 
            {.}
    )
    
    
    ## datasets table ----
    output$datasets_table = renderDT(
        df_datasets_format, 
        extensions = c('Buttons', 'Scroller'),
        options = list(dom = 'Bfrtip',
                       # autoWidth = TRUE,
                       # columnDefs = list(list(width = '100px', targets = "_all")),
                       buttons = list('colvis', 
                                      list(
                                          extend = 'collection',
                                          buttons = list(
                                              list(extend='csv',
                                                   filename = paste0('DataPortalReport-Datasets'#, 
                                                                     # '_', Sys.Date() %>% with_tz(tzone = 'America/Los_Angeles')
                                                   )
                                              ),
                                              list(extend='excel',
                                                   title = NULL,
                                                   filename = paste0('DataPortalReport-Datasets'#, 
                                                                     # '_', Sys.Date() %>% with_tz(tzone = 'America/Los_Angeles')
                                                   )
                                              )
                                          ),
                                          text = 'Download Data')
                       ),
                       scrollX = TRUE,
                       scrollY = 350,
                       scroller = TRUE,
                       deferRender = TRUE),
        class = 'cell-border stripe',
        server = TRUE, ## NOTE: TRUE may not allow for download of the full file
        rownames = FALSE
    )
    
    ## resources table ----
    output$resources_table = renderDT(
        df_resources_format, 
        extensions = c('Buttons', 'Scroller'),
        options = list(dom = 'Bfrtip',
                       buttons = list('colvis', 
                                      list(
                                          extend = 'collection',
                                          buttons = list(
                                              list(extend='csv',
                                                   filename = paste0('DataPortalReport-Resources_'#, 
                                                                     # '_', Sys.Date() %>% with_tz(tzone = 'America/Los_Angeles')
                                                   )
                                              ),
                                              list(extend='excel',
                                                   title = NULL,
                                                   filename = paste0('DataPortalReport-Resources_'#, 
                                                                     # '_', Sys.Date() %>% with_tz(tzone = 'America/Los_Angeles')
                                                   )
                                              )
                                          ),
                                          text = 'Download Data')
                       ),
                       scrollX = TRUE,
                       scrollY = 350,
                       scroller = TRUE,
                       deferRender = TRUE),
        class = 'cell-border stripe',
        server = TRUE, ## NOTE: TRUE may not allow for download of the full file
        rownames = FALSE
    )
    
}


# Run application 
shinyApp(ui = ui, server = server)
