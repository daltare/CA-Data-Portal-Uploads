Author:
	Andrew Dix Hill; https://github.com/AndrewDixHill/CEDEN_to_DataCAGov ; andrew.hill@waterboards.ca.gov

Agency:
	California State Water Resource Control Board (SWRCB)
	Office of Information Management and Analysis (OIMA)

Purpose:
	This script is intended to query, clean and calculate new fields for
datasets from an internal SWRCB DataMart of CEDEN data. This script also applies a data 
quality estimate to every record and cleans the original dataset of non-ASCII characters.
This data quality estimate is calculated from a data quality decision tree currently in progress. 
Outputs datasets of this tool will be:
	All_CEDEN_Sites -- https://data.ca.gov/dataset/surface-water-%E2%80%93-sampling-location-information-%E2%80%93-ceden
	WaterChemistry -- https://data.ca.gov/dataset/surface-water-%E2%80%93-chemistry-%E2%80%93-ceden
	Tissue -- https://data.ca.gov/dataset/surface-water-%E2%80%93-aquatic-organism-tissue-samples-%E2%80%93-ceden
	Toxicity -- https://data.ca.gov/dataset/surface-water-%E2%80%93-toxicity-%E2%80%93-ceden
	Habitat -- https://data.ca.gov/dataset/surface-water-%E2%80%93-habitat-%E2%80%93-ceden
	Benthic -- https://data.ca.gov/dataset/surface-water-%E2%80%93-benthic-macroinvertebrates-%E2%80%93-ceden

	Additional datasets:
	SafeToSwim (subset of WaterChemistry) -- https://data.ca.gov/dataset/surface-water-%E2%80%93-sampling-location-information-%E2%80%93-ceden temporary
	Sites_for_SafeToSwim -- https://data.ca.gov/dataset/data-update-automation/resource/ffdbb549-5bb9-4d07-92a4-7fb3f4eb42e6#{view-graph:{graphOptions:{hooks:{processOffset:{},bindEvents:{}}}},graphOptions:{hooks:{processOffset:{},bindEvents:{}}},view-map:{lonField:!Longitude,latField:!Latitude}} temporary
	Pesticides -- unavailable
	Sites_for_Pesticides -- unavailable
	WQX_Stations -- subset of All_CEDEN_Sites dataset of sites with valid datums
	CyanoToxins -- unavailable
	Sites_for_CyanoToxins -- unavailable
	

How to use this script:
	From a powershell prompt (windows), call python and specify
	the complete path to this file. Below is an example, where XXXXXXX should be replaced
	with the filename and the path should be specific to the file location:
	python C:\\Users\\AHill\\Downloads\\XXXXXXX.py

Prerequisites:
	Windows platform (not strictly a requirement but I was unable to get this library
		working on a mac... I tried)
	Python 3.X
	pyodbc library for python.  See https://github.com/mkleehammer/pyodbc
	dkan library for python.    See https://github.com/GetDKAN/pydkan

Scripts in the "WorkingScripts" folder can be repurposed but are not supported or intended for 
use outside of testing.
