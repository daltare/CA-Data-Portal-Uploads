# Define the datasets to be downloaded (NOTE: Existing versions of the downloaded files with today's date will automatically be overwritten)
# The filename is the name of the file that will be output (the current date will also be appended to the name) - I'm using the tile of the link to the dataset on the SMARTS webpage as the filename, to make it easier to keep track of the data source
# The html_id is the identifier of the button/link for the given dataset in the html code on the SMARTS website (use the 'developer' too in the browser to find this in the html code)
    dataset_list <- list(dataset1 = list(filename = 'Industrial_Ad_Hoc_Reports_-_Parameter_Data', 
                                         html_id = 'intDataFileDowloaddataFileForm:industrialRawDataLink',
                                         resource_id = '7871e8fe-576d-4940-acdf-eca0b399c1aa',
                                         date_fields = c('SAMPLE_DATE', 'DISCHARGE_START_DATE'), # NOTE: The number of items in this field should be the same as the number of items in the following two fields
                                         time_fields = c('SAMPLE_TIME', 'DISCHARGE_START_TIME'),
                                         timestamp_names = c('SAMPLE_TIMESTAMP', 'DISCHARGE_START_TIMESTAMP')),
                         dataset2 = list(filename = 'Industrial_Application_Specific_Data', 
                                         html_id = 'intDataFileDowloaddataFileForm:industrialAppLink',
                                         resource_id = '33e69394-83ec-4872-b644-b9f494de1824',
                                         date_fields = c('NOI_PROCESSED_DATE', 'NOT_EFFECTIVE_DATE'), # NOTE: The number of items in this field should be the same as the number of items in the following two fields
                                         time_fields = c('', ''),
                                         timestamp_names = c('NOI_PROCESSED_TIMESTAMP', 'NOT_EFFECTIVE_TIMESTAMP')),
                         dataset3 = list(filename = 'Construction_Ad_Hoc_Reports_-_Parameter_Data', 
                                         html_id = 'intDataFileDowloaddataFileForm:constructionAdhocRawDataLink',
                                         resource_id = '0c441948-5bb9-4d50-9f3c-ca7dab256056', 
                                         date_fields = c('SAMPLE_DATE', 'EVENT_START_DATE', 'EVENT_END_DATE'), # NOTE: The number of items in this field should be the same as the number of items in the following two fields
                                         time_fields = c('SAMPLE_TIME', '', ''),
                                         timestamp_names = c('SAMPLE_TIMESTAMP', 'EVENT_START_TIMESTAMP', 'EVENT_END_TIMESTAMP')),    
                         dataset4 = list(filename = 'Construction_Application_Specific_Data', 
                                         html_id = 'intDataFileDowloaddataFileForm:constructionAppLink',
                                         resource_id = '8a0ed456-ca69-4b29-9c5b-5de3958dc963', 
                                         date_fields = c('NOI_PROCESSED_DATE', 'NOT_EFFECTIVE_DATE', 'CERTIFICATION_DATE',
                                                         'CONSTRUCTION_COMMENCEMENT_DATE', 'COMPLETE_GRADING_DATE', 'COMPLETE_PROJECT_DATE'), # NOTE: The number of items in this field should be the same as the number of items in the following two fields
                                         time_fields = c('', '', '', '', '', ''),
                                         timestamp_names = c('NOI_PROCESSED_TIMESTAMP', 'NOT_EFFECTIVE_TIMESTAMP', 'CERTIFICATION_TIMESTAMP',
                                                             'CONSTRUCTION_COMMENCEMENT_TIMESTAMP', 'COMPLETE_GRADING_TIMESTAMP', 'COMPLETE_PROJECT_TIMESTAMP'))
                         )

    # dataset5 = list(filename = 'put_new_name_here', # to add a new dataset, enter here and un-comment these lines
    #                 html_id = 'put_new_id_here', 
    #                 resource_id = 'put_new_resource_id_here'))
    # dataset6 = list(filename = 'put_new_name_here', # to add a new dataset, enter here and un-comment these lines
    #                 html_id = 'put_new_id_here', 
    #                 resource_id = 'put_new_resource_id_here'))
    # dataset7 = list(filename = 'put_new_name_here', # to add a new dataset, enter here and un-comment these lines
    #                 html_id = 'put_new_id_here', 
    #                 resource_id = 'put_new_resource_id_here'))
    # dataset8 = list(filename = 'put_new_name_here', # to add a new dataset, enter here and un-comment these lines
    #                 html_id = 'put_new_id_here', 
    #                 resource_id = 'put_new_resource_id_here'))
    # dataset9 = list(filename = 'put_new_name_here', # to add a new dataset, enter here and un-comment these lines
    #                 html_id = 'put_new_id_here', 
    #                 resource_id = 'put_new_resource_id_here'))
    # dataset10 = list(filename = 'put_new_name_here', # to add a new dataset, enter here and un-comment these lines
    #                 html_id = 'put_new_id_here', 
    #                 resource_id = 'put_new_resource_id_here'))
    
    
    forms_datasets_list <- list(forms.dataset.1 = list(reports_page_id = 'publicMenuForm:industriaReportLink', # Industrial - WDIDs with a Level 1 or 2 Pollutant
                                                       report_id = 'industReportForm:level12ReportLink',
                                                       run_report_id = 'level12Report:level12RunReportButton',
                                                       export_excel_id = 'level12Report:level12ExcelButton',
                                                       filename = 'Industrial_Current_WDIDs_with_Level_1_or_2_Pollutant',
                                                       smarts_file_name = 'sample.xls',
                                                       smarts_file_type = 'xls',
                                                       resource_id = 'put_new_resource_id_here'), 
                                forms.datasets.2 = list(reports_page_id = 'publicMenuForm:commandLink6', # Construction - Risk Report
                                                        report_id = 'constRepForm:swConstructionReports-riskLevelsLink',
                                                        run_report_id = 'form1:reportsCriteria-runReportButton',
                                                        export_excel_id = 'riskReportForm:riskLevelReport-excelButton',
                                                        filename = 'Construction_Risk_Report',
                                                        smarts_file_name = 'file.csv',
                                                        smarts_file_type = 'csv',
                                                        resource_id = 'put_new_resource_id_here'))
