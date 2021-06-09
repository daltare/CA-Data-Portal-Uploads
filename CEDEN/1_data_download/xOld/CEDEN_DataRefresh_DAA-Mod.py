'''

Author:
	Andrew Dix Hill; https://github.com/AndrewDixHill/CEDEN_to_DataCAGov ; andrew.hill@waterboards.ca.gov

Agency:
	California State Water Resource Control Board (SWRCB)
	Office of Information Management and Analysis (OIMA)

Purpose:
	This script is intended to query, clean and calculate new fields for
datasets from an internal SWRCB DataMart of CEDEN data. The original datasets contain
non-ascii characters and restricted character such as tabs, feedlines, return lines, etc which
this script removes. This script also applies a data quality estimate to every record.
The data quality estimate is calculated from a data quality decision tree in development.
	In addition, this script subsets the newly created datasets into smaller and more
specialized data based on a list of analytes. This script also publishes each
dataset to the open data water portal on data.ca.gov.

How to use this script:
	From a powershell prompt (windows), call python and specify
	the complete path to this file. Below is an example, where XXXXXXX should be replaced
	with the filename and the path should be specific to the file location:
	python C:\\Users\\AHill\\Downloads\\XXXXXXX.py

Prerequisites:
	Windows platform (not strictly requirement but I was unable to get this library
		working on a mac... I tried)
	Python 3.X
	pyodbc library for python.  See https://github.com/mkleehammer/pyodbc
	dkan library for python.    See https://github.com/GetDKAN/pydkan
	set appropriate server addresses, usernames, passwords for both the water boards DataMart and
	Data.ca.gov's account.
	Please also use the pyodbc's drivers() tool to determine which sql driver is on your machine.
		ie., "pyodbc.drivers()" in python environment will return list of available sql drivers

'''

# Import the necessary libraries of python code
import pyodbc
import os
import csv
import re
from datetime import datetime
import string
import getpass
from dkan.client import DatasetAPI


##### These are not currently in use as we have decided not to calculate RB values for each site
#from dkan.client import DatasetAPI
#import time
#import json
#import pandas as pd
#import numpy as np
#import shapefile as shp
#from shapely.geometry import Polygon, Point

####   These lines are also not in use yet
#siteDictFile = "C:\\Users\\AHill\\Documents\\CEDEN_DataMart\\WQX_Stations.txt"
#polygon_in = shp.Reader("C:\\Users\\AHill\\Documents\\CEDEN_DataMart\\Regional_Board_Boundaries\\CA_WA_RBs_WGS84.shp")
#polygon = polygon_in.shapes()
#shpfilePoints = [shape.points for shape in polygon]
#polygons = shpfilePoints


# decodeAndStrip takes a string and filters each character through the printable variable. It returns a filtered string.
def decodeAndStrip(t):
	filter1 = ''.join(filter(lambda x: x in printable, str(t)))
	return filter1

###########################################################################################################################
#########################        Dictionary of code fixer 	below	###########################
###########################################################################################################################

# rename_Dict_Column simplifies the process of creating a new key in the dictionary and removing the old key.
def rename_Dict_Column(dictionary, oldName, Newname):
	dictionary[Newname] = dictionary[oldName]
	dictionary.pop(oldName)
	
def remove_Dict_Column(dictionary, removeName):
	dictionary.pop(removeName)

#The DictionaryFixer creates custom QA code dictionaries for each dataset since not all columns are present or
# have the same name between datasets. Ex: Water chemistry has a "ProgramName" column while all of the other datasets use "Program"
# the Custom dictionary is called Mod_CodeColumns and the ".pop" deletes unwanted keys. If you see a key error,
# check to see if your dataset has a column with that same name. If it is different, rename using rename_Dict_Column.
#  If it doesn't exist, use remove_Dict_Column() to remove it as below. Use the re.match() function to match multiple
#  versions of filenames.  For instance BenthicData.csv or BenthicData_prior_to_1999 can both be match with the
# re.match() function.
def DictionaryFixer(CodeColumns, filename ):
	Mod_CodeColumns = CodeColumns.copy()
	if filename == 'WQX_Stations':
		################################## Delete #################
		remove_Dict_Column(Mod_CodeColumns, "Analyte")
		remove_Dict_Column(Mod_CodeColumns, "Result")
		remove_Dict_Column(Mod_CodeColumns, "MatrixName")
		remove_Dict_Column(Mod_CodeColumns, "ResultsReplicate")
		remove_Dict_Column(Mod_CodeColumns, "QACode")
		remove_Dict_Column(Mod_CodeColumns, "BatchVerification")
		remove_Dict_Column(Mod_CodeColumns, "ResultQualCode")
		remove_Dict_Column(Mod_CodeColumns, "Latitude")
		remove_Dict_Column(Mod_CodeColumns, "SampleTypeCode")
		remove_Dict_Column(Mod_CodeColumns, "SampleDate")
		remove_Dict_Column(Mod_CodeColumns, "ProgramName")
		remove_Dict_Column(Mod_CodeColumns, "CollectionReplicate")
	if filename == 'BenthicData':
		################# Rename #################
		rename_Dict_Column(Mod_CodeColumns, oldName="SampleTypeCode", Newname="SampleType")
		rename_Dict_Column(Mod_CodeColumns, oldName="ResultQualCode", Newname="ResQualCode")
		################################## Delete #################
		remove_Dict_Column(Mod_CodeColumns, "Analyte")
		remove_Dict_Column(Mod_CodeColumns, "Result")
		remove_Dict_Column(Mod_CodeColumns, "MatrixName")
		remove_Dict_Column(Mod_CodeColumns, "ResultsReplicate")
		remove_Dict_Column(Mod_CodeColumns, "QACode")
		remove_Dict_Column(Mod_CodeColumns, "BatchVerification")
		remove_Dict_Column(Mod_CodeColumns, "Datum")
	if re.match('TissueData', filename):
		################# Rename #################
		rename_Dict_Column(Mod_CodeColumns, oldName="MatrixName", Newname="Matrix")
		rename_Dict_Column(Mod_CodeColumns, oldName="ResultsReplicate", Newname="ResultReplicate")
		################################## Delete #################
		remove_Dict_Column(Mod_CodeColumns, "ResultQualCode")
	if re.match('WaterChemistry',filename):
		################# Rename #################
		rename_Dict_Column(Mod_CodeColumns, oldName="ProgramName", Newname="Program")
	if re.match('Toxicity', filename):
		################# Rename #################
		rename_Dict_Column(Mod_CodeColumns, oldName="ProgramName", Newname="Program")
		rename_Dict_Column(Mod_CodeColumns, oldName="BatchVerification", Newname="BatchVerificationCode")
		################################## Delete #################
		remove_Dict_Column(Mod_CodeColumns, "ResultsReplicate")
	if re.match('HabitatData', filename):
		################# Rename #################
		rename_Dict_Column(Mod_CodeColumns, oldName="ProgramName", Newname="Program")
		################################## Delete #################
		remove_Dict_Column(Mod_CodeColumns, "ResultsReplicate")
		remove_Dict_Column(Mod_CodeColumns, "Result")
		remove_Dict_Column(Mod_CodeColumns, "BatchVerification")
	if filename == 'CyanoToxinData':
		################# Rename #################
		rename_Dict_Column(Mod_CodeColumns, oldName="BatchVerification", Newname='BatchVerificationCode')
		rename_Dict_Column(Mod_CodeColumns, oldName="ResultQualCode", Newname="ResQualCode")
		rename_Dict_Column(Mod_CodeColumns, oldName="ResultsReplicate", Newname="Replicate")
		rename_Dict_Column(Mod_CodeColumns, oldName="Analyte", Newname="AnalyteName")
		################################## Delete #################
		remove_Dict_Column(Mod_CodeColumns, "ProgramName")
		remove_Dict_Column(Mod_CodeColumns, "CollectionReplicate")
	if filename == 'IR_ToxicityData':
		################# Rename #################
		rename_Dict_Column(Mod_CodeColumns, oldName="ResultQualCode", Newname="ResQualCode")
		rename_Dict_Column(Mod_CodeColumns, oldName="ProgramName", Newname="Program")
		rename_Dict_Column(Mod_CodeColumns, oldName="Latitude", Newname="TargetLatitude")
		#Batch verification exists but should not be used for IR as of 1/25/2018
		#rename_Dict_Column(Mod_CodeColumns, oldName="BatchVerification", Newname="BatchVerificationCode")
		################################## Delete #################
		remove_Dict_Column(Mod_CodeColumns, "ResultsReplicate")
		# Batch verification exists but should not be used for IR as of 1/25/2018
		remove_Dict_Column(Mod_CodeColumns, "BatchVerification")
		remove_Dict_Column(Mod_CodeColumns, "Datum")
	if filename == 'IR_BenthicData':
		################# Rename #################
		rename_Dict_Column(Mod_CodeColumns, oldName="ResultQualCode", Newname="ResQualCode")
		rename_Dict_Column(Mod_CodeColumns, oldName="SampleTypeCode", Newname="SampleType")
		rename_Dict_Column(Mod_CodeColumns, oldName="Latitude", Newname="TargetLatitude")
		################################## Delete #################
		remove_Dict_Column(Mod_CodeColumns, "Analyte")
		remove_Dict_Column(Mod_CodeColumns, "Result")
		remove_Dict_Column(Mod_CodeColumns, "MatrixName")
		remove_Dict_Column(Mod_CodeColumns, "ResultsReplicate")
		remove_Dict_Column(Mod_CodeColumns, "QACode")
		remove_Dict_Column(Mod_CodeColumns, "BatchVerification")
		remove_Dict_Column(Mod_CodeColumns, "Datum")
	if filename == 'IR_WaterChemistryData':
		################# Rename #################
		rename_Dict_Column(Mod_CodeColumns, oldName="ResultQualCode", Newname="ResQualCode")
		rename_Dict_Column(Mod_CodeColumns, oldName="Analyte", Newname="AnalyteName")
		rename_Dict_Column(Mod_CodeColumns, oldName="ResultsReplicate", Newname="Replicate")
		rename_Dict_Column(Mod_CodeColumns, oldName="Latitude", Newname="TargetLatitude")
		################################## Delete #################
		remove_Dict_Column(Mod_CodeColumns, "BatchVerification")
		remove_Dict_Column(Mod_CodeColumns, "CollectionReplicate")
		remove_Dict_Column(Mod_CodeColumns, "Datum")
	if filename == 'IR_STORET_2010':
		################# Rename #################
		rename_Dict_Column(Mod_CodeColumns, oldName="Analyte", Newname="AnalyteName")
		rename_Dict_Column(Mod_CodeColumns, oldName="ResultQualCode", Newname="ResQualCode")
		rename_Dict_Column(Mod_CodeColumns, oldName="ResultsReplicate", Newname="Replicate")
		rename_Dict_Column(Mod_CodeColumns, oldName="Latitude", Newname="TargetLatitude")
		################################## Delete #################
		#  Batch verification exists but should not be used for IR as of 1/25/2018
		remove_Dict_Column(Mod_CodeColumns, "BatchVerification")
		remove_Dict_Column(Mod_CodeColumns, "CollectionReplicate")
		remove_Dict_Column(Mod_CodeColumns, "Datum")
	if filename == 'IR_STORET_2012':
		################# Rename #################
		rename_Dict_Column(Mod_CodeColumns, oldName="Analyte", Newname="AnalyteName")
		rename_Dict_Column(Mod_CodeColumns, oldName="ResultQualCode", Newname="ResQualCode")
		rename_Dict_Column(Mod_CodeColumns, oldName="ResultsReplicate", Newname="Replicate")
		rename_Dict_Column(Mod_CodeColumns, oldName="Latitude", Newname="TargetLatitude")
		################################## Delete #################
		#  Batch verification exists but should not be used for IR as of 1/25/2018
		remove_Dict_Column(Mod_CodeColumns, "BatchVerification")
		remove_Dict_Column(Mod_CodeColumns, "CollectionReplicate")
		remove_Dict_Column(Mod_CodeColumns, "Datum")
	if filename == 'IR_NWIS':
		################# Rename #################
		rename_Dict_Column(Mod_CodeColumns, oldName="Analyte", Newname="AnalyteName")
		rename_Dict_Column(Mod_CodeColumns, oldName="ResultQualCode", Newname="ResQualCode")
		rename_Dict_Column(Mod_CodeColumns, oldName="ResultsReplicate", Newname="Replicate")
		rename_Dict_Column(Mod_CodeColumns, oldName="Latitude", Newname="TargetLatitude")
		################################## Delete #################
		#  Batch verification exists but should not be used for IR as of 1/25/2018
		remove_Dict_Column(Mod_CodeColumns, "BatchVerification")
		remove_Dict_Column(Mod_CodeColumns, "CollectionReplicate")
		remove_Dict_Column(Mod_CodeColumns, "Datum")
	if filename == 'IR_Field':
		################# Rename #################
		rename_Dict_Column(Mod_CodeColumns, oldName="ResultQualCode", Newname="ResQualCode")
		rename_Dict_Column(Mod_CodeColumns, oldName="ResultsReplicate", Newname="ResultReplicate")
		rename_Dict_Column(Mod_CodeColumns, oldName="Latitude", Newname="TargetLatitude")
		# IR_Field has Analyte and AnalyteName columns
		Mod_CodeColumns["AnalyteName"] = Mod_CodeColumns["Analyte"]
		################################## Delete #################
		#  Batch verification exists but should not be used for IR as of 1/25/2018
		remove_Dict_Column(Mod_CodeColumns, "BatchVerification")
		remove_Dict_Column(Mod_CodeColumns, "Datum")
	if filename == 'IR_TissueData':
		################# Rename #################
		rename_Dict_Column(Mod_CodeColumns, oldName="ResultQualCode", Newname="ResQualCode")
		rename_Dict_Column(Mod_CodeColumns, oldName="ResultsReplicate", Newname="ResultReplicate")
		rename_Dict_Column(Mod_CodeColumns, oldName="MatrixName", Newname="Matrix")
		rename_Dict_Column(Mod_CodeColumns, oldName="Latitude", Newname="TargetLatitude")
		################################## Delete #################
		#  Batch verification exists but should not be used for IR as of 1/25/2018
		remove_Dict_Column(Mod_CodeColumns, "BatchVerification")
		remove_Dict_Column(Mod_CodeColumns, "Datum")
	return Mod_CodeColumns
###########################################################################################################################
#########################        Dictionary of code fixer 	above	###########################
###########################################################################################################################

# data_retrieval is the meat of this script. It takes the tables dictionary defined above, two dates (specified
# below), and a save location for the output files.
def data_retrieval(tables, saveLocation, sep, extension, For_IR):
	# initialize writtenFiles where we will store the output complete file paths in list format.
	writtenFiles = {}
	try:
		# a python cursor is a synonym to a recordset or resultset.
		# this is the connection to SWRCB internal DataMart. Server, IUD, PWD are set as environmental variables so
		# no passwords are in plain text, see "Main" below for importing examples. UID
		# below create a connection
		# Please be sure that you have the 'ODBC Driver 11 for SQL Server' driver installed on your machine.
		cnxn = pyodbc.connect(Driver='SQL Server Native Client 11.0', Server=SERVER1, uid=UID, pwd=PWD)
		# creates a cursor which will execute the sql statement
		cursor = cnxn.cursor()
	except:
		print("Couldn't connect to %s. It is down or you might have a typo somewhere. Make sure you've got the "
		      "right password and Server id. Check internet "
		      "connection." % SERVER1)
	# initialize an AllSites dictionary
	AllSites = {}
	# LAt/Long strings in variables
	Latitude, Longitude = ['Latitude', 'Longitude', ]
	# commonly used string for filename creation.
	range_1950 = '_prior_to_1999'
	range_2000 = '_2000-2009'
	range_2010 = '_2010-present'
	# This loop iterates on each item in the tables variable below
	for count, (filename, table) in enumerate(tables.items()):
		# creates and addes the full path of the file to be created for the full datasets as
		# well as the date divided subsets. the filename_xx variables are used as part of the
		# file writing process
		writtenFiles[filename] = os.path.join(saveLocation, '%s%s' % (filename, extension))
		filename_1950 = os.path.join(saveLocation, '%s%s' % (filename + range_1950, extension))
		filename_2000 = os.path.join(saveLocation, '%s%s' % (filename + range_2000, extension))
		filename_2010 = os.path.join(saveLocation, '%s%s' % (filename + range_2010, extension))
		writtenFiles[filename + range_1950] = filename_1950
		writtenFiles[filename + range_2000] = filename_2000
		writtenFiles[filename + range_2010] = filename_2010
		# Sine the WQX file has to be first, we use count == 0 as a way to filter these actions
		# for the first iteration only. we want to grab the file path for the WQX file
		if count == 0:
			WQXfile = writtenFiles[filename]
		##############################################################################
		########################## SQL Statement  ####################################
		##############################################################################
		# The DM_WQX_Stations_MV table should not be filtered by date but the significant difference between this
		# table and the others is that we are not calculating new fields a do not have to add columns. Also,
		# benthic dataset does not need the Datum column
		if table == 'DM_WQX_Stations_MV':
			sql = "SELECT * FROM %s ;" % table
			cursor.execute(sql)
			columns = [desc[0].replace('TargetL', 'L') for desc in cursor.description]
		else:
			sql = "SELECT * FROM %s" % table
			cursor.execute(sql)
			# IR tables do not have lat/long renamed
			if For_IR:
				columns = [desc[0] for desc in cursor.description]
				Latitude, Longitude = ['TargetLatitude', 'TargetLongitude', ]
			else:
				columns = [desc[0].replace('TargetL', 'L') for desc in cursor.description]
			# Check to see if datum is in the column headers, add two new column names
			if 'Datum' in columns:
				columns += ['DataQuality'] + ['DataQualityIndicator']
			else:
				columns += ['DataQuality'] + ['DataQualityIndicator'] + ['Datum']
		##############################################################################
		########################## SQL Statement  ####################################
		##############################################################################
		#initialize Sitecolumns
		Sitecolumns = []
		#  the First key in Tables must be the WQX_Stations. When count is 0, we do NOT read in
		#  the WQX stations. If the script has already processed past WQX_Stations (count>0) then we read in the file
		#  for accessing the datum associated with the station codes.
		if count > 0 and not For_IR:
			with open(WQXfile, 'r', newline='', encoding='utf8') as WQX_sites_reader:
				WQX_Sites = {}
				SitesCounter = 0
				# we use the csv python module a lot here. It is standard and allows us to
				# iterate over each line of a file.
				reader = csv.reader(WQX_sites_reader, delimiter=sep, lineterminator='\n')
				# we can treat "reader" like a list of every line in a file. That is how
				# we iterate over the file
				for row in reader:
					# if this is the very first line of a file, it should be the headers
					# Grab the headers and store them to SiteColumns
					if SitesCounter == 0:
						Sitecolumns = row
						SitesCounter += 1
					# create a dictionary of columns and the current row
					# this way we can access each row's values by name
					# we do this a lot in this file
					SiterowDict = dict(zip(Sitecolumns, row))
					# create a dictionary of station codes that return the datum value
					WQX_Sites[SiterowDict['StationCode']] = SiterowDict['Datum']
		if count == count:  ### Change back to  1 == 1:
			# this is where we create a reader for each file in the "tables" variable
			# using the filename iterable
			with open(writtenFiles[filename], 'w', newline='', encoding='utf8') as csvfile:
				# we open a file and write the first row with the DictWriter tool
				dw = csv.DictWriter(csvfile, fieldnames=columns, delimiter=sep, lineterminator='\n')
				dw.writeheader()
				# we create a writer object which we will only call towards the very end of the data
				# quality estimation
				writer = csv.writer(csvfile, csv.QUOTE_MINIMAL, delimiter=sep, lineterminator='\n')
				# here we create and open three additional files where we will write rows if the meet
				# our logical criteria. Notice that the all have the columns variable and the dates
				# refer to the general time division we are using. Prior to 1999, 2000-2009, 2010-present
				with open(filename_1950, 'w', newline='', encoding='utf8') as csv1950:
					dw1950 = csv.DictWriter(csv1950, fieldnames=columns, delimiter=sep, lineterminator='\n')
					dw1950.writeheader()
					writer1950 = csv.writer(csv1950, csv.QUOTE_MINIMAL, delimiter=sep, lineterminator='\n')
					with open(filename_2000, 'w', newline='', encoding='utf8') as csv2000:
						dw2000 = csv.DictWriter(csv2000, fieldnames=columns, delimiter=sep, lineterminator='\n')
						dw2000.writeheader()
						writer2000 = csv.writer(csv2000, csv.QUOTE_MINIMAL, delimiter=sep, lineterminator='\n')
						with open(filename_2010, 'w', newline='', encoding='utf8') as csv2010:
							dw2010 = csv.DictWriter(csv2010, fieldnames=columns, delimiter=sep,
							                        lineterminator='\n')
							dw2010.writeheader()
							writer2010 = csv.writer(csv2010, csv.QUOTE_MINIMAL, delimiter=sep,
							                        lineterminator='\n')
							#########################
							# if the table is the WQX stations table
							if table == 'DM_WQX_Stations_MV':
								for row in cursor:
									# we have to make a distinction between None, 'None', and ''
									# 'None' and '' are used specifically in the datasets, but
									# None gets translated to 'None' unless we replace it with
									# '' explicitly
									row = [str(word) if word is not None else '' for word in row]
									# strip all other invalid characters using decodeAndStrip definition
									filtered = [decodeAndStrip(t) for t in list(row)]
									# join the column list and the new filtered list
									# to make a dictionary that we can use througout this script
									recordDict = dict(zip(columns, filtered))
									# Sometime the Longitude gets entered as 119 instead of -119...
									# make sure Longitude value is negative and less than 10000 (could be projected)
									try:
										long = float(recordDict[Longitude])
										if 0. < long < 10000.0 :
											recordDict[Longitude] = -long
									except ValueError:
										pass
									# write the values of our recordDictionary to the WQX file
									writer.writerow(list(recordDict.values()))
							else:
								# if not WQX filename
								# create a dictionary of code values specific to the filenames needs
								# see Dictionary Fixer above
								Mod_CodeColumns = DictionaryFixer(CodeColumns, filename)
								for row in cursor:
									# see None, 'None' and '' above
									filtered = [decodeAndStrip(t) if t is not None else '' for t in list(row)]
									# we have to make columns and filtered the same length otherwise python
									# just uses the shorter of the two. since we want to add a column for
									# datum, data quality and estimator, but sometimes only 2, we use the while
									# function to iterate
									while len(columns) > len(filtered):
										filtered += ['']
									# create a dictionary of columns and our current file row!!
									recordDict = dict(zip(columns, filtered))
									# make sure Longitude value is negative and less than 10000 (could be projected)
									try:
										long = float(recordDict[Longitude])
										if 0. < long < 10000.0 :
											recordDict[Longitude] = -long
									except ValueError:
										pass
									#####  IR and Benthic datasets do not need datum added  #####
									if For_IR or filename == 'BenthicData':
										pass
									# Everyone else ...
									# check to see if the current record's station code is in the variable
									# WQX_Sites and if it is, then store that datum value to our current record
									# otherwise store 'NR' not recorded
									else:
										if recordDict['StationCode'] in WQX_Sites:
											recordDict['Datum'] = WQX_Sites[recordDict['StationCode']]
										else:
											recordDict['Datum'] = 'NR'
									#####  ^^^^^^^^^^^^^^^^^^^^^  #####
									DQ = []
									############
									# This is the begining of the data quality estimation
									# for each list in the modified dictionary of QA codes
									for codeCol in list(Mod_CodeColumns):
										# if the list is QACode
										if codeCol == 'QACode':
											# for each value in the specific record
											# split the value up by commas and return a list
											# ie.  codeVal may be 'QAC,DNR,LOB' which is a string
											# this would return ['QAC', 'DNR', 'LOB'] which is an iterable list
											for codeVal in recordDict[codeCol].split(','):
												# if QAC or DNR or LOB is in the QACode list
												if codeVal in list(Mod_CodeColumns[codeCol]):
													# add that numerical value to a temporary variable called "DQ"
													DQ += [Mod_CodeColumns[codeCol][codeVal]]
												# For this example record, QAC DNR and LOB would each add a
												# numerical value to DQ. DQ might be [2, 3, 1]
												# we continue to use DQ to collect all of the numberical values as we
												#  iterate through all of the lists in Mod_CodeColumns
										if codeCol == 'StationCode':
											# if a record has 000NONPJ or any variants in the StationCode value,
											# than add 0 to DQ.
											# elif any values are in the StationCode list, add those values to DQ.
											if bool(re.search('000NONPJ', recordDict[codeCol])):
												DQ += [0]
											elif codeVal in list(Mod_CodeColumns[codeCol]):
												DQ += [Mod_CodeColumns[codeCol][codeVal]]
										elif codeCol == 'Analyte' or codeCol == 'AnalyteName':
											# search for surrogate and mark DQ with a 0
											if bool(re.search('[Ss]urrogate', recordDict[codeCol])):
												DQ += [0]
										elif codeCol == 'ResultQualCode' or codeCol == 'ResQualCode':
											for codeVal in [recordDict[codeCol]]:
												# Special Rules
												# for both IR2018_WQ and IR2018_Tissue, if the ResultQualCode has a
												# DNQ, then we have to make sure the year is less than 2008 but
												# dates for these datasets were reported as monthdayyear, so we need
												# the last 4. If the year is less than 2008, we mark DQ with a reject
												# number. If it is greater than 2008, we mark it with a pass value
												if table == 'IR2018_WQ' or table == 'IR2018_Tissue' and codeVal == 'DNQ':
													yearTest = int(recordDict['SampleDate'][-4:])
													if isinstance(yearTest, int) and yearTest < 2008:
														DQ += [6]
														#add rule identifier so that we seen the quality indicator reflect this rule
												elif codeVal == 'DNQ' and int(recordDict['SampleDate'][:4]) < 2008:
													#### add rule identifier so that we seen the quality indicator reflect this rule
													DQ += [6]
												elif codeVal == 'ND':
													# the Benthic dataset can have an ND value as long as the result
													# is not positive. Record is a pass if less than or equal to zero
													# reject if result is positive
													try:
														RQC = recordDict['Result']
														if not isinstance(RQC, str) and RQC > 0:
															DQ += [6]
														else:
															DQ += [1]
													except KeyError:
														DQ += [1]
												elif codeVal in list(Mod_CodeColumns[codeCol]):
													# End of Special Rules for ResultQualCode
													# check each value an add numerical key to DQ
													DQ += [Mod_CodeColumns[codeCol][codeVal]]
										elif codeCol == 'Result':
											# for the Result we just need to make sure that results can be empty if
											# ND is the ResultQualCode or ResQualCode
											# yes they have different names and yes I should have made a more generic
											#  search for these terms.
											#
											for codeVal in recordDict[codeCol]:
												if codeVal == '':
													if 'ResultQualCode' in recordDict.keys():
														if 'ND' == recordDict['ResultQualCode']:
															DQ += [1]
													if 'ResQualCode' in recordDict.keys():
														if 'ND' == recordDict['ResQualCode']:
															DQ += [1]
												else:
													if codeVal in list(Mod_CodeColumns[codeCol]):
														DQ += [Mod_CodeColumns[codeCol][codeVal]]
										else:
											# for all other non Special Rules, check each values in the record column
											#  to see if its in the dictionary of QA codes. if it is in the
											# apropriate list, then add the numerical code to DQ
											for codeVal in [recordDict[codeCol]]:
												if codeVal in list(Mod_CodeColumns[codeCol]):
													DQ += [Mod_CodeColumns[codeCol][codeVal]]
									try:
										# we get the max value of DQ
										MaxDQ = max(DQ)
									except ValueError:
										# if DQ doesn't have any values, it means that it slipped through the cracks
										# and is some kind of an error. Check it out
										MaxDQ = 7
										DQ += [MaxDQ, ]
									## This marks the beginning of the Quality indicator column value generator
									QInd = []
									# now that we have DQ with all of the numerical codes that can up for that record...
									for codeCol in list(Mod_CodeColumns.keys()):
										# make sure codeValList is empty
										codeValList = []
										ValuesEqMaxDQ = []
										# get the record specific values from each QA list and store
										# them to codeValList
										if codeCol == 'QACode':
											codeValList = recordDict[codeCol].split(',')
										else:
											codeValList = [recordDict[codeCol], ]
										# for each code in our new list for this particular record, we check to see
										# if the corresponding numerical code value is equal to the max value of DQ.
										# If it is we save the particular code to ValuesEqMaxDQ. IfValuesEqMaxDQ
										# isn't empty, we save the QA code list name with the offending values to "QInd"
										for codeVal in codeValList:
											# This part is tricky.
											if codeVal in Mod_CodeColumns[codeCol] and MaxDQ == int(Mod_CodeColumns[codeCol][codeVal]):
												ValuesEqMaxDQ += [codeVal, ]
										if not ValuesEqMaxDQ == []:
											QInd += [codeCol + ':' + ','.join(str(instance) for instance in ValuesEqMaxDQ)]
									# A word about that DQ variable.
									# DQ might host a long list of numbers but if there is ever a zero, that whole
									# record should be classified as a QC record. If there isnt a zero and the
									# maximum value is a 1, then that record passed our data quality estimate
									# unblemished. If there isn't a zero and the max DQ values is greater than 1,
									# then ... we get the max value and store the corresponding value (from the
									# DQ_Codes dictionary, defined above). If the Max DQ is 6 (which is a reject
									# record) and QInd is empty, then this is a special rule case and we label it as
									# such. Otherwise, we throw all of the QInd information into the Quality
									# indicator column. QInd might look like:
									#   ['ResQualCode:npr,kqed', 'BatchVerificationCode:lol,btw,omg', ]
									# and the this gets converted and stored into the records new column called Data
									# Quality indicator a:
									# 'ResQualCode:npr,kqed; BatchVerificationCode:lol,btw,omg'
									if min(DQ) == 0:
										recordDict['DataQuality'] = DQ_Codes[0]
									elif max(DQ) == 1:
										recordDict['DataQuality'] = DQ_Codes[1]
									else:
										recordDict['DataQuality'] = DQ_Codes[MaxDQ]
										if MaxDQ == 6 and QInd == []:
											recordDict['DataQualityIndicator'] = 'ResultQualCode Special Rules'
										else:
											recordDict['DataQualityIndicator'] = '; '.join(str(ColVal) for ColVal in QInd)
									# Now that we have something very special called
									#
									###############      recordDict     ##############
									#
									# we write its values to each of our open files... millions of times.
									if not For_IR:
										recordYear = int(recordDict['SampleDate'][:4])
										if recordYear < 2000:
											writer1950.writerow(list(recordDict.values()))
										elif 1999 < recordYear < 2010:
											writer2000.writerow(list(recordDict.values()))
										elif recordYear > 2009:
											writer2010.writerow(list(recordDict.values()))
									writer.writerow(list(recordDict.values()))
									# for each line that we process, all of the sites found in benthic, water chem,
									# tissue, habitat, WQX, Toxicity we store the Stationname, Lat/Long and datum to
									# this temporary thing called:
									#                              AllSites
									if recordDict['StationCode'] not in AllSites:
										AllSites[recordDict['StationCode']] = [recordDict['StationName'],
										                                       recordDict[Latitude], recordDict[Longitude],
										                                       recordDict['Datum'], ]
				# these lines remove files that do not have anything but headers
				# Sometimes we create empty files to hold data but nothing ends up
				# going into them. So we erase them based on # of bytes which is 2000
				if os.stat(filename_1950).st_size < 2000:
					os.remove(filename_1950)
					writtenFiles.pop(filename + range_1950)
				if os.stat(filename_2000).st_size < 2000:
					os.remove(filename_2000)
					writtenFiles.pop(filename + range_2000)
				if os.stat(filename_2010).st_size < 2000:
					os.remove(filename_2010)
					writtenFiles.pop(filename + range_2010)
				print("Finished data retrieval for the %s table" % filename)
	return writtenFiles, AllSites

####################################################################################
############################# Select By Analyte Subset #############################
####################################################################################

# this is a tool to subset the main CEDEN datasets using the Analyte column ( or whatever column you specify)
def selectByAnalyte(path, fileName, analytes, newFileName, field_filter, sep,
                    For_IR=False):
	# we create a variable that store the entire path of the input file
	file = os.path.join(path, fileName)
	# we create a variable that store the entire path of the output file
	fileOut = os.path.join(path, newFileName)
	# we initialize the Analyte_Sites and columns so we can store stuff in it
	Analyte_Sites = {}
	columns = []
	# the IR tables use TargetLat/Long while we renamed the other tables.
	if For_IR:
		Latitude, Longitude = ['TargetLatitude', 'TargetLongitude', ]
	else:
		Latitude, Longitude = ['Latitude', 'Longitude', ]
	# using with open..... again
	with open(file, 'r', newline='', encoding='utf8') as txtfile:
		reader = csv.reader(txtfile, delimiter=sep, lineterminator='\n')
		with open(fileOut, 'w', newline='', encoding='utf8') as txtfileOut:
			writer = csv.writer(txtfileOut, csv.QUOTE_MINIMAL, delimiter=sep, lineterminator='\n')
			count = 0
			for row in reader:
				row = [str(word) if word is not None else '' for word in row]
				if count == 0:
					columns = row
					writer.writerow(row)
					count += 1
					continue
				rowDict = dict(zip(columns, row))
				# here is the magic of this whole definition
				# field_filter is how we extract the current records analyte and see if it is in the
				# analytes list. If it is in the list then we write the row to fileout.
				# we also add that row's location information to a Analyte_Sites variable
				if rowDict[field_filter] in analytes:
					writer.writerow(row)
					if rowDict['StationCode'] not in Analyte_Sites:
						Analyte_Sites[rowDict['StationCode']] = [rowDict['StationName'], rowDict[Latitude],
						                                         rowDict[Longitude], rowDict['Datum']]
	# IR tables don't need a sites file
	if not For_IR:
		Sites = os.path.join(path, 'Sites_for_' + newFileName)
		with open(Sites, 'w', newline='', encoding='utf8') as Sites_Out:
			Sites_writer = csv.writer(Sites_Out, csv.QUOTE_MINIMAL, delimiter=sep, lineterminator='\n')
			AllSites_dw = csv.DictWriter(Sites_Out, fieldnames=['StationName', 'SiteCode', 'Latitude', 'Longitude',
			                                                    'Datum'], delimiter=sep, lineterminator='\n')
			AllSites_dw.writeheader()
			for key, value in Analyte_Sites.items():
				Sites_writer.writerow([value[0], key, value[1], value[2], value[3]])
		return newFileName, fileOut, 'Sites_for_' + newFileName, Sites
	else:
		return newFileName, fileOut, 'Sites_for_' + newFileName


				####################################################################################
				############################# Select By Analyte Subset #############################
				####################################################################################


##############################################################################
########################## Main Statement  ###################################
##############################################################################

# Necessary variables imported from user's environmental variables.
# To protect windows machines from recursive spawning, this script is meant to be run from a command line interface,
# not in a piecemeal fashion.
if __name__ == "__main__":
	# Is this to be run for IR Tables?
	For_IR = False
	#  This is the filter that every cell in each dataset gets passed through. From the "string" library, we are only
	# allowing printable characters except pipes, quotes, tabs, returns, control breaks, etc.
	printable = set(string.printable) - set('|\"\t\r\n\f\v')
	# What type of delimiter should files have? "|" or "\t" are common
	if not For_IR:
		sep = ','
		extension = '.csv'
	else:
		sep = '\t'
		extension = '.txt'
	print('\n\n\n\n')
	# This is the SWRCB internal server set as a local environmental variable for the user.
	# Save the server address to the SERVER1 environmental variable for your account.
	SERVER1 = os.environ.get('SERVER1')
	# SERVER1 = '172.22.33.39, 2866'
	# Save the data.ca.gov user information to the UID environmental variable for your account.
	UID = os.environ.get('UID')
	# Save the data.ca.gov password associated with your UserID information to the PWD environmental variable for your
	# account.
	# PWD = 'OIMAP@ssw0rd'
	PWD = os.environ.get('PWD')
	# Choose a location to write files locally.
	### you can change this to point to a different location but it does automatically get your user information.
	first = 'C:\\Users\\%s\\Documents' % getpass.getuser()
	# All output files will be saved in this folder
	saveLocation = os.path.join(first, 'CEDEN_Datasets')
	if not os.path.isdir(saveLocation):
		print('\tCreating the CEDEN_DataMart folder for datasets as \n\t\t%s\n' % saveLocation)
		os.mkdir(saveLocation)
	###############################################################################
	##################        Dictionaries for QA codes below 		###############
	###############################################################################
	# The following python dictionaries refer to codes and their corresponding data quality value as determined by
	# Melissa Morris of SWRCB, Office of Information Management and Analysis. 0: QC record, 1: Passed QC, 2: Needs some
	# review, 3: Spatial Accuracy Unknown, 4: Needs extensive review, 5: unknown data quality, 6: reject data record  (as
	#  of 1/22/18)
	QA_Code_list = {"AWM": 1, "AY": 2, "BB": 2, "BBM": 2, "BCQ": 1, "BE": 2, "BH": 1, "BLM": 4, "BRKA": 2, "BS": 2,
	                "BT": 6, "BV": 4, "BX": 4, "BY": 4, "BZ": 4, "BZ15": 2, "C": 1, "CE": 4, "CIN": 2, "CJ": 2, "CNP": 2,
	                "CQA": 1, "CS": 2, "CSG": 2, "CT": 2, "CVH": 1, "CVHB": 4, "CVL": 1, "CVLB": 4, "CZM": 2, "D": 1,
	                "DB": 2, "DBLOD": 2, "DBM": 2, "DF": 2, "DG": 1, "DO": 1, "DRM": 2, "DS": 1, "DT": 1, "ERV": 4, "EUM": 4,
	                "EX": 4, "F": 2, "FCL": 2, "FDC": 2, "FDI": 2, "FDO": 6, "FDP": 2, "FDR": 1, "FDS": 1, "FEU": 6, "FIA": 6,
	                "FIB": 4, "FIF": 6, "FIO": 4, "FIP": 4, "FIT": 2, "FIV": 6, "FLV": 6, "FNM": 6, "FO": 2, "FS": 6, "FTD": 6,
	                "FTT": 6, "FUD": 6, "FX": 4, "GB": 2, "GBC": 4, "GC": 1, "GCA": 1, "GD": 1, "GN": 4, "GR": 4, "H": 2, "H22": 4,
	                "H24": 4, "H8": 2, "HB": 2, "HD": 4, "HH": 2, "HNO2": 2, "HR": 1, "HS": 4, "HT": 1, "IE": 2, "IF": 2, "IL": 4,
	                "ILM": 2, "ILN": 2, "ILO": 2, "IM": 2, "IP": 4, "IP5": 4, "IPMDL2": 4, "IPMDL3": 4, "IPRL": 4, "IS": 4,
	                "IU": 4, "IZM": 2, "J": 2, "JA": 2, "JDL": 2, "LB": 2, "LC": 4, "LRGN": 6, "LRIL": 6, "LRIP": 6, "LRIU": 6,
	                "LRJ": 6, "LRJA": 6, "LRM": 6, "LRQ": 6, "LST": 6, "M": 2, "MAL": 1, "MN": 4, "N": 2, "NAS": 2, "NBC": 2,
	                "NC": 1, "NG": 1, "NMDL": 1, "None": 1, "NR": 5, "NRL": 1, "NTR": 1, "OA": 2, "OV": 2, "P": 4, "PG": 4,
	                "PI": 4, "PJ": 1, "PJM": 1, "PJN": 1, "PP": 4, "PRM": 4, "Q": 4, "QAX": 1, "QG": 4, "R": 6, "RE": 1, "REL": 1,
	                "RIP": 6, "RIU": 6, "RJ": 6, "RLST": 6, "RPV": 4, "RQ": 2, "RU": 4, "RY": 4, "SC": 1, "SCR": 2, "SLM": 1, "TA": 4,
	                "TAC": 1, "TC": 4, "TCI": 4, "TCT": 4, "TD": 4, "TH": 4, "THS": 4, "TK": 4, "TL": 2, "TNC": 2, "TNS": 1, "TOQ": 4,
	                "TP": 4, "TR": 6, "TS": 4, "TW": 2, "UF": 2, "UJ": 2, "UKM": 4, "ULM": 4, "UOL": 2, "VCQ": 2, "VQN": 2, "VC": 2,
	                "VBB": 2, "VBS": 2, "VBY": 4, "VBZ": 4, "VBZ15": 2, "VCJ": 2, "VCO": 2, "VCR": 2, "VD": 1, "VDO": 1, "VDS": 1,
	                "VELB": 1, "VEUM": 4, "VFDP": 2, "VFIF": 6, "VFNM": 6, "VFO": 2, "VGB": 2, "VGBC": 4, "VGN": 4, "VH": 2, "VH24": 4,
	                "VH8": 2, "VHB": 2, "VIE": 2, "VIL": 4, "VILN": 4, "VILO": 2, "VIP": 4, "VIP5": 4, "VIPMDL2": 4, "VIPMDL3": 4,
	                "VIPRL": 4, "VIS": 4, "VIU": 4, "VJ": 2, "VJA": 2, "VLB": 2, "VLMQO": 2, "VM": 2, "VNBC": 2, "VNC": 1, "VNMDL": 1,
	                "VNTR": 1, "VPJM": 1, "VPMQO": 2, "VQAX": 1, "VQCA": 4, "VQCP": 4, "VR": 6, "VRBS": 6, "VRBZ": 6, "VRDO": 6,
	                "VRE": 1, "VREL": 1, "VRGN": 6, "VRIL": 6, "VRIP": 6, "VRIU": 6, "VRJ": 6, "VRLB": 6, "VRLST": 6, "VRQ": 2,
	                "VRVQ": 6, "VS": 2, "VSC": 1, "VSCR": 2, "VSD3": 1, "VTAC": 1, "VTCI": 4, "VTCT": 4, "VTNC": 2, "VTOQ": 4, "VTR": 6,
	                "VTW": 4, "VVQ": 6, "WOQ": 4,  }
	BatchVerificationCode_list = {"NA": 5, "NR": 5, "VAC": 1, "VAC,VCN": 6, "VAC,VMD": 2, "VAC,VMD,VQI": 4,
	                              "VAC,VQI": 4, "VAC,VR": 6, "VAF": 1, "VAF,VMD": 2, "VAF,VQI": 4, "VAP": 1,
	                              "VAP,VI": 4, "VAP,VQI": 4, "VCN": 6, "VLC": 1, "VLC,VMD": 2, "VLC,VMD,VQI": 4,
	                              "VLC,VQI": 4, "VLF": 1, "VMD": 2, "VQI": 4, "VQI,VTC": 4, "VQN": 5, "VR": 6, "VTC": 2}
	ResultQualCode_list = {"/oC": 4, "<": 1, "<=": 1, "=": 1, ">": 1, ">=": 1, "A": 1, "CG": 4, "COL": 1, "DNQ": 1,
	                       "JF": 1, "NA": 6, "ND": 1, "NR": 6, "NRS": 6, "NRT": 6, "NSI": 1, "P": 1, "PA": 1, "w/C": 4,
	                       "": 1, "Systematic Contamination": 4, }
	Latitude_list = {"-88": 0, "": 6, '0.0': 6, }
	Result_list = {"": 1, }
	StationCode_list = {"LABQA": 0, "LABQA_SWAMP": 0, "000NONPJ": 0, "FIELDQA": 0, "Non Project QA Sample": 0,
	                    "Laboratory QA Sample": 0, "Field QA sample": 0, "FIELDQA SWAMP": 0, "000NONSW": 0, }
	SampleTypeCode_list = {"LabBlank": 0, "CompBLDup": 0, "LCS": 0, "CRM": 0, "FieldBLDup_Grab": 0, "FieldBLDup_Int": 0,
	                       "FieldBLDup": 0, "FieldBlank": 0, "TravelBlank": 0, "EquipBlank": 0, "DLBlank": 0,
	                       "FilterBlank": 0, "MS1": 0, "MS2": 0, "MS3": 0, "MSBLDup": 0, }
	ProgramName_list = {}
	SampleDate_list = {"Jan  1 1950 12:00AM": 0, }
	Analyte_list = {"Surrogate": 0, }
	MatrixName_list = {"blankwater": 0, "Blankwater": 0, "labwater": 0, "blankmatrix": 0, }
	CollectionReplicate_list = {"0": 1, "1": 1, "2": 0, "3": 0, "4": 0, "5": 0, "6": 0, "7": 0, "8": 0, }
	ResultsReplicate_list = {"0": 1, "1": 1, "2": 0, "3": 0, "4": 0, "5": 0, "6": 0, "7": 0, "8": 0, }
	Datum_list = {"NR": 3, }
	DQ_Codes = {0: "MetaData", 1: "Passed", 2: "Some review needed", 3: "Spatial accuracy unknown",
	            4: "Extensive review needed", 5: "Unknown data quality", 6: "Reject record", 7: 'Error in data'}
	# the CodeColumns variable is a dictionary template for each dataset. Some datasets do not have all of these columns
	# and as such have to be removed with the DictionaryFixer definition below.
	CodeColumns = {"QACode": QA_Code_list, "BatchVerification": BatchVerificationCode_list,
	              "ResultQualCode": ResultQualCode_list, "Latitude": Latitude_list, "Result": Result_list,
	              "StationCode": StationCode_list, "SampleTypeCode": SampleTypeCode_list, "SampleDate": SampleDate_list,
	              "ProgramName": ProgramName_list, "Analyte": Analyte_list, "MatrixName": MatrixName_list,
	              "CollectionReplicate": CollectionReplicate_list, "ResultsReplicate": ResultsReplicate_list,
	              "Datum": Datum_list, }
	# This is a Python dictionary of filenames and their Datamart names. This can be expanded by adding to the end of
	#  the list. The FIRST key in this dictionary MUST be WQX_Stations. If For_IR is set to False, it will complete the
	# normal weekly 5 tables. If For_IR is set to True, this script will complete the IR tables.
	tables = {}  # initializes tables variable
	if not For_IR:
		tables = {"WQX_Stations": "DM_WQX_Stations_MV", "WaterChemistryData": "WQDMart_MV",
		          "ToxicityData": "ToxDmart_MV", "TissueData": "TissueDMart_MV",
		          "BenthicData": "BenthicDMart_MV", "HabitatData": "HabitatDMart_MV", }
	if For_IR:
		# Below is the line to run the IR tables.
		tables = {"IR_WaterChemistryData": "IR2018_WQ",
		          "IR_ToxicityData": "IR2018_Toxicity", "IR_BenthicData": "IR2018_Benthic",
		          "IR_STORET_2010": "IR2018_Storet_2010_2012", "IR_STORET_2012": "IR2018_Storet_2012_2017",
		          "IR_NWIS": "IR2018_NWIS", "IR_Field": "IR2018_Field", "IR_TissueData": "IR2018_Tissue", }
	###########################################################################################################################
	#########################        Dictionaries for QA codes above		###############################################
	###########################################################################################################################

	startTime = datetime.now()
	# This line runs the functions defined above.
	# The following line does the majority of this script
	FILES, AllSites = data_retrieval(tables, saveLocation, sep=sep, extension=extension, For_IR=For_IR)
	print("\n\n\t\tCompleted data retrieval and processing\n\t\t\tfrom internal DataMart\n\n")
	print("this is the FILES object: \n", FILES, "\n\n")
	# write out the All sites variable... This includes all sites in the Chemistry, benthic, toxicity, tissue and
	# habitat datasets.
	if not For_IR:
		AllSites_path = os.path.join(saveLocation, 'All_CEDEN_Sites.csv')
		with open(AllSites_path, 'w', newline='', encoding='utf8') as AllSites_csv_file:
			AllSites_dw = csv.DictWriter(AllSites_csv_file,
			                             fieldnames=['StationName', 'SiteCode', 'Latitude', 'Longitude',
			                                         'Datum', ], delimiter=sep, lineterminator='\n')
			AllSites_dw.writeheader()
			AllSites_writer = csv.writer(AllSites_csv_file, csv.QUOTE_MINIMAL, delimiter=sep, lineterminator='\n')
			for key, value in AllSites.items():
				AllSites_writer.writerow([value[0], key, value[1], value[2], value[3]])
		FILES['All_CEDEN_Sites'] = AllSites_path
	totalTime = datetime.now() - startTime
	seconds = totalTime.seconds
	minutes = seconds // 60
	seconds = seconds - minutes * 60
	print("Data retrieval and processing took %d minutes and %d seconds" % (minutes, seconds))
	# if For_IR is False, saved datasets are likely:
	# FILES["WQX_Stations"]
	# FILES["WaterChemistryData"]
	# FILES["ToxicityData"]
	# FILES["TissueData"]
	# FILES["BenthicData"]
	# FILES["HabitatData"]
	# use FILES["TableKey"] to subset future datasets, as in example below...

	############## Subsets of WQ dataset for Cyanotoxins  ###
	if not For_IR:
		############## Subsets of WQ dataset for Safe To Swim  ###
		print("\nStarting data subset for Safe to Swim...")
		WaterChem = FILES['WaterChemistryData']
		path, fileName = os.path.split(WaterChem)
		analytes = ['E. coli', 'Enterococcus', 'Coliform, Total', 'Coliform, Fecal', ]
		newFileName = 'SafeToSwim' + extension
		column_filter = 'Analyte'
		name, location, sitesname, siteslocation = selectByAnalyte(path=path, fileName=fileName, newFileName=newFileName, analytes=analytes,
		                field_filter=column_filter, sep=sep)
		FILES[name] = location
		FILES[sitesname] = siteslocation
		#SafeToSwim_Sites = 'SafeToSwim_Sites' + extension
		print("\t\tFinished writing data subset for Safe to Swim\n\n")
		############## Subsets of WQ dataset for Safe To Swim  ###

		############## Subsets of WQ dataset for Pesticides
		print("\nStarting data subset for Pesticides....")
		analytes = ["Acetamiprid", "Acibenzolar-S-methyl", "Aldicarb", "Aldicarb ", "Aldicarb Sulfone",
		            "Aldicarb Sulfoxide", "Aldrin", "Aldrin, Particulate", "Allethrin", "Ametryn", "Aminocarb", "AMPA",
		            "Anilazine", "Aspon", "Atraton", "Atrazine", "Azinphos Ethyl", "Azinphos Methyl", "Azoxystrobin",
		            "Barban", "Bendiocarb", "Benfluralin", "Benomyl", "Bensulfuron Methyl", "Bentazon", "Bifenox",
		            "Bifenthrin", "Bispyribac Sodium", "Bolstar", "Bromacil", "Captafol", "Captan", "Carbaryl",
		            "Carbendazim", "Carbofuran", "Carbophenothion", "Carfentrazone Ethyl", "Chlorantraniliprole",
		            "Chlordane", "Chlordane, cis-", "Chlordane, cis-, Particulate", "Chlordane, Technical",
		            "Chlordane, trans-", "Chlordane, trans-, Particulate", "Chlordene, cis-", "Chlordene, trans-",
		            "Chlorfenapyr", "Chlorfenvinphos", "Chlorobenzilate", "Chlorothalonil", "Chlorpropham",
		            "Chlorpyrifos", "Chlorpyrifos Methyl", "Chlorpyrifos Methyl, Particulate",
		            "Chlorpyrifos Methyl/Fenchlorphos", "Chlorpyrifos, Particulate", "Cinerin-2", "Ciodrin",
		            "Clomazone", "Clothianidin", "Coumaphos", "Cyanazine", "Cyantraniliprole", "Cycloate", "Cyfluthrin",
		            "Cyfluthrin, beta-", "Cyfluthrin-1", "Cyfluthrin-2", "Cyfluthrin-3", "Cyfluthrin-4",
		            "Cyhalofop-butyl", "Cyhalothrin", "Cyhalothrin lambda-", "Cyhalothrin, gamma-",
		            "Cyhalothrin, lambda-1", "Cyhalothrin, lambda-2", "Cypermethrin", "Cypermethrin-1",
		            "Cypermethrin-2", "Cypermethrin-3", "Cypermethrin-4", "Cyprodinil", "Dacthal",
		            "Dacthal, Particulate", "DCBP(p,p')", "DDD(o,p')", "DDD(o,p'), Particulate", "DDD(p,p')",
		            "DDD(p,p'), Particulate", "DDE(o,p')", "DDE(o,p'), Particulate", "DDE(p,p')",
		            "DDE(p,p'), Particulate", "DDMU(p,p')", "DDMU(p,p'), Particulate", "DDT(o,p')",
		            "DDT(o,p'), Particulate", "DDT(p,p')", "DDT(p,p'), Particulate", "Deltamethrin",
		            "Deltamethrin/Tralomethrin", "Demeton", "Demeton-O", "Demeton-s", "Desethyl-Atrazine",
		            "Desisopropyl-Atrazine", "Diazinon", "Diazinon, Particulate", "Dichlofenthion", "Dichlone",
		            "Dichloroaniline, 3,5-", "Dichlorobenzenamine, 3,4-", "Dichlorophenyl Urea, 3,4-",
		            "Dichlorophenyl-3-methyl Urea, 3,4-", "Dichlorvos", "Dichrotophos", "Dicofol", "Dicrotophos",
		            "Dieldrin", "Dieldrin, Particulate", "Diflubenzuron", "Dimethoate", "Dioxathion", "Diphenamid",
		            "Diphenylamine", "Diquat", "Disulfoton", "Dithiopyr", "Diuron", "Endosulfan I",
		            "Endosulfan I, Particulate", "Endosulfan II", "Endosulfan II, Particulate", "Endosulfan Sulfate",
		            "Endosulfan Sulfate, Particulate", "Endrin", "Endrin Aldehyde", "Endrin Ketone",
		            "Endrin, Particulate", "EPN", "EPTC", "Esfenvalerate", "Esfenvalerate/Fenvalerate",
		            "Esfenvalerate/Fenvalerate-1", "Esfenvalerate/Fenvalerate-2", "Ethafluralin", "Ethion", "Ethoprop",
		            "Famphur", "Fenamiphos", "Fenchlorphos", "Fenhexamid", "Fenitrothion", "Fenpropathrin",
		            "Fensulfothion", "Fenthion", "Fenuron", "Fenvalerate", "Fipronil", "Fipronil Amide",
		            "Fipronil Desulfinyl", "Fipronil Desulfinyl Amide", "Fipronil Sulfide", "Fipronil Sulfone",
		            "Flonicamid", "Fluometuron", "Fluridone", "Flusilazole", "Fluvalinate", "Fluxapyroxad", "Folpet",
		            "Fonofos", "Glyphosate", "Halosulfuron Methyl", "HCH, alpha-", "HCH, alpha-, Particulate",
		            "HCH, beta-", "HCH, beta-, Particulate", "HCH, delta-", "HCH, delta-, Particulate", "HCH, gamma-",
		            "HCH, gamma-, Particulate", "Heptachlor", "Heptachlor Epoxide", "Heptachlor Epoxide, Particulate",
		            "Heptachlor Epoxide/Oxychlordane", "Heptachlor Epoxide/Oxychlordane, Particulate",
		            "Heptachlor, Particulate", "Hexachlorobenzene", "Hexachlorobenzene, Particulate", "Hexazinone",
		            "Hydroxyatrazine, 2-", "Hydroxycarbofuran, 3- ", "Hydroxypropanal, 3-", "Imazalil", "Indoxacarb",
		            "Isofenphos", "Isoxaben", "Jasmolin-2", "Kepone", "Ketocarbofuran, 3-", "Leptophos", "Linuron",
		            "Malathion", "Merphos", "Methamidophos", "Methidathion", "Methiocarb", "Methomyl", "Methoprene",
		            "Methoxychlor", "Methoxychlor, Particulate", "Methoxyfenozide",
		            "Methyl (3,4-dichlorophenyl)carbamate", "Mevinphos", "Mexacarbate", "Mirex", "Mirex, Particulate",
		            "Molinate", "Monocrotophos", "Monuron", "Naled", "Neburon", "Nonachlor, cis-",
		            "Nonachlor, cis-, Particulate", "Nonachlor, trans-", "Nonachlor, trans-, Particulate",
		            "Norflurazon", "Oxadiazon", "Oxadiazon, Particulate", "Oxamyl", "Oxychlordane",
		            "Oxychlordane, Particulate", "Oxyfluorfen", "Paraquat", "Parathion, Ethyl", "Parathion, Methyl",
		            "PCNB", "Pebulate", "Pendimethalin", "Penoxsulam", "Permethrin", "Permethrin, cis-",
		            "Permethrin, trans-", "Perthane", "Phenothrin", "Phorate", "Phosalone", "Phosmet", "Phosphamidon",
		            "Piperonyl Butoxide", "Pirimiphos Methyl", "PrAllethrin", "Procymidone", "Profenofos",
		            "Profluralin", "Prometon", "Prometryn", "Propachlor", "Propanil", "Propargite", "Propazine",
		            "Propham", "Propoxur", "Pymetrozin", "Pyrethrin-2", "Pyrimethanil", "Quinoxyfen", "Resmethrin",
		            "Safrotin", "Secbumeton", "Siduron", "Simazine", "Simetryn", "Sulfallate", "Sulfotep",
		            "Tebuthiuron", "Tedion", "Terbufos", "Terbuthylazine", "Terbutryn", "Tetrachloro-m-xylene",
		            "Tetrachlorvinphos", "Tetraethyl Pyrophosphate", "Tetramethrin", "T-Fluvalinate", "Thiamethoxam",
		            "Thiobencarb", "Thionazin", "Tokuthion", "Total DDDs", "Total DDEs", "Total DDTs", "Total HCHs",
		            "Total Pyrethrins", "Toxaphene", "Tralomethrin", "Tributyl Phosphorotrithioate, S,S,S-",
		            "Trichlorfon", "Trichloronate", "Triclopyr", "Tridimephon", "Vinclozolin", ]
		WaterChem = FILES["WaterChemistryData"]
		path, fileName = os.path.split(WaterChem)
		newFileName = 'Pesticides' + extension
		column_filter = 'DW_AnalyteName'
		name, location, sitesname, siteslocation = selectByAnalyte(path=path, fileName=fileName, newFileName=newFileName, analytes=analytes,
		                field_filter=column_filter, sep=sep)
		FILES[name] = location
		FILES[sitesname] = siteslocation
		print("\t\tFinished writing data subset for Pesticides\n\n")
	############## ^^^^^^^^^^^^  Subsets of datasets for Pesticides
    
    
    
######################################### ORGANICS (BELOW) ####################################################################
import pyodbc
import os
import csv
import re
from datetime import datetime
import string
import getpass
from dkan.client import DatasetAPI
    
print("\nStarting data subset for Organics....")
FILES = {'Organics.csv': 'C:\\Users\\daltare\\Documents\\CEDEN_Datasets\\Organics.csv', 'WaterChemistryData': 'C:\\Users\\daltare\\Documents\\CEDEN_Datasets\\WaterChemistryData.csv',}
sep = ','
extension = '.csv'
# Get the 'selectByAnalyte' function
### The analytes below are derived from the dbo_Parameter_Groups table in the datamart, filtered for organics (and "orgainics")
analytes = ["18a-Oleanane, Total", "Acenaphthene, Dissolved", "Acenaphthene, Particulate", "Acenaphthene, Total", "Acenaphthene-d10(Surrogate), Total", "Acenaphthylene, Dissolved", "Acenaphthylene, Particulate", "Acenaphthylene, Total", "Acenaphthylene-d8(Surrogate), Dissolved", "Acenaphthylene-d8(Surrogate), Particulate", "Acenaphthylene-d8(Surrogate), Total", "Acetaminophen, Total", "Acetaminophen-13C2-15N(Surrogate), Total", "Acetamiprid, Dissolved", "Acetamiprid, Total", "Acetone, Total", "Acibenzolar-S-methyl, Dissolved", "Acibenzolar-S-methyl, Particulate", "Acifluorfen, Dissolved", "Acifluorfen, Total", "Acrolein, Total", "Acrylonitrile, Total", "Alachlor ethanesulfonic acid, Not Recorded", "Alachlor oxanilic acid, Not Recorded", "Alachlor, Dissolved", "Alachlor, Not Recorded", "Alachlor, Particulate", "Alachlor, Total", "Albuterol, Total", "Albuterol-d3(Surrogate), Total", "Aldicarb Sulfone, Dissolved", "Aldicarb Sulfone, Not Recorded", "Aldicarb Sulfone, Total", "Aldicarb Sulfoxide, Dissolved", "Aldicarb Sulfoxide, Not Recorded", "Aldicarb Sulfoxide, Total", "Aldicarb, Dissolved", "Aldicarb, Not Recorded", "Aldicarb, Total", "Aldrin(Surrogate), Dissolved", "Aldrin(Surrogate), Particulate", "Aldrin(Surrogate), Total", "Aldrin, Dissolved", "Aldrin, Particulate", "Aldrin, Total", "Aldrin-13C12(Surrogate), Total", "Allethrin, Dissolved", "Allethrin, Particulate", "Allethrin, Total", "Alpha Linolenic Acid, Total", "Alprazolam, Total", "Alprazolam-d5(Surrogate), Total", "Ametryn, Dissolved", "Ametryn, Total", "Aminocarb, Total", "Aminopyralid, Total", "Amitriptyline, Total", "Amitriptyline-d5(Surrogate), Total", "Amlodipine, Total", "AMPA(Surrogate), Total", "AMPA, Dissolved", "AMPA, Total", "Amphetamine, Total", "Amphetamine-d5(Surrogate), Total", "Anilazine, Total", "Aniline, Total", "Anthracene, Dissolved", "Anthracene, Particulate", "Anthracene, Total", "Anthracene-d10(Surrogate), Dissolved", "Anthracene-d10(Surrogate), Total", "Arachidonic, Total", "Aspon, Total", "Atenolol, Total", "Atenolol-d7(Surrogate), Total", "Atorvastatin, Total", "Atraton, Dissolved", "Atraton, Total", "Atrazine, Dissolved", "Atrazine, Not Recorded", "Atrazine, Particulate", "Atrazine, Total", "Atrazine-13C3(Surrogate), Dissolved", "Atrazine-13C3(Surrogate), Total", "Atrazine-d5(Surrogate), Total", "Atrazine-Desisopropyl-2-Hydroxy, Total", "Azinphos Ethyl, Total", "Azinphos Methyl oxon, Dissolved", "Azinphos Methyl oxon, Particulate", "Azinphos Methyl, Dissolved", "Azinphos Methyl, Not Recorded", "Azinphos Methyl, Particulate", "Azinphos Methyl, Total", "Azinphos-methyl oxygen analog, Not Recorded", "Azithromycin, Total", "Azobenzene, Total", "Barban(Surrogate), Dissolved", "Barban, Total", "Bendiocarb, Dissolved", "Benfluralin, Dissolved", "Benfluralin, Particulate", "Benfluralin, Total", "Benomyl, Dissolved", "Benomyl, Total", "Benomyl/Carbendazim, Total", "Bensulfuron Methyl, Dissolved", "Bensulfuron Methyl, Total", "Bensulide, Not Recorded", "Bensulide, Total", "Bentazon, Dissolved", "Bentazon, Total", "Benz(a)anthracene, Dissolved", "Benz(a)anthracene, Particulate", "Benz(a)anthracene, Total", "Benz(a)anthracene-d12(Surrogate), Dissolved", "Benz(a)anthracene-d12(Surrogate), Particulate", "Benz(a)anthracene-d12(Surrogate), Total", "Benz(a)anthracene-d12/Chrysene-d12(Surrogate), Dissolved", "Benz(a)anthracene-d12/Chrysene-d12(Surrogate), Particulate", "Benz(a)anthracenes/Chrysenes, C1-, Dissolved", "Benz(a)anthracenes/Chrysenes, C1-, Particulate", "Benz(a)anthracenes/Chrysenes, C1-, Total", "Benz(a)anthracenes/Chrysenes, C2-, Dissolved", "Benz(a)anthracenes/Chrysenes, C2-, Particulate", "Benz(a)anthracenes/Chrysenes, C2-, Total", "Benz(a)anthracenes/Chrysenes, C3-, Dissolved", "Benz(a)anthracenes/Chrysenes, C3-, Particulate", "Benz(a)anthracenes/Chrysenes, C3-, Total", "Benz(a)anthracenes/Chrysenes, C4-, Dissolved", "Benz(a)anthracenes/Chrysenes, C4-, Particulate", "Benz(a)anthracenes/Chrysenes, C4-, Total", "Benzaldehyde, Total", "Benzene, Total", "Benzidine, Total", "Benzo(a)fluoranthene, Total", "Benzo(a)pyrene, Dissolved", "Benzo(a)pyrene, Particulate", "Benzo(a)pyrene, Total", "Benzo(a)pyrene-d12(Surrogate), Dissolved", "Benzo(a)pyrene-d12(Surrogate), Particulate", "Benzo(a)pyrene-d12(Surrogate), Total", "Benzo(b)fluoranthene, Dissolved", "Benzo(b)fluoranthene, Particulate", "Benzo(b)fluoranthene, Total", "Benzo(b)fluoranthene-d12(Surrogate), Dissolved", "Benzo(b)fluoranthene-d12(Surrogate), Particulate", "Benzo(b)fluoranthene-d12(Surrogate), Total", "Benzo(b/j/k)fluoranthene, Total", "Benzo(b/j/k)fluoranthene-d12(Surrogate), Total", "Benzo(b/k)fluoranthene-d12(Surrogate), Dissolved", "Benzo(b/k)fluoranthene-d12(Surrogate), Particulate", "Benzo(b/k)fluoranthene-d12(Surrogate), Total", "Benzo(e)pyrene, Dissolved", "Benzo(e)pyrene, Particulate", "Benzo(e)pyrene, Total", "Benzo(e)pyrene-d12(Surrogate), Total", "Benzo(g,h,i)perylene, Dissolved", "Benzo(g,h,i)perylene, Particulate", "Benzo(g,h,i)perylene, Total", "Benzo(g,h,i)perylene-d12(Surrogate), Dissolved", "Benzo(g,h,i)perylene-d12(Surrogate), Particulate", "Benzo(g,h,i)perylene-d12(Surrogate), Total", "Benzo(j)fluoranthene, Total", "Benzo(j/k)fluoranthene, Dissolved", "Benzo(j/k)fluoranthene, Particulate", "Benzo(j/k)fluoranthene, Total", "Benzo(k)fluoranthene, Dissolved", "Benzo(k)fluoranthene, Particulate", "Benzo(k)fluoranthene, Total", "Benzo(k)fluoranthene-d12(Surrogate), Dissolved", "Benzo(k)fluoranthene-d12(Surrogate), Particulate", "Benzo(k)fluoranthene-d12(Surrogate), Total", "Benzoic Acid, Total", "Benzothiophene, C1-, Total", "Benzothiophene, C2-, Total", "Benzothiophene, C3-, Total", "Benzothiophene, Total", "Benzoylecgonine, Total", "Benzoylecgonine-d8(Surrogate), Total", "Benztropine, Total", "Benztropine-d3(Surrogate), Total", "Benzyl Alcohol, Total", "Betamethasone, Total", "Bifenox, Total", "Bifenthrin, Dissolved", "Bifenthrin, Not Recorded", "Bifenthrin, Particulate", "Bifenthrin, Total", "Biphenyl, Dissolved", "Biphenyl, Particulate", "Biphenyl, Total", "Biphenyl-d10(Surrogate), Dissolved", "Biphenyl-d10(Surrogate), Particulate", "Biphenyl-d10(Surrogate), Total", "Bis(2-chloro-1-methylethyl) ether, Total", "Bis(2-chloroethoxy)methane, Total", "Bis(2-chloroethyl)ether, Total", "Bis(2-chloroisopropyl) ether, Total", "Bis(2-ethylhexyl)adipate, Total", "Bis(2-ethylhexyl)phthalate, Dissolved", "Bis(2-ethylhexyl)phthalate, Particulate", "Bis(2-ethylhexyl)phthalate, Total", "Bis(2-ethylhexyl)phthalate-d4(Surrogate), Dissolved", "Bis(2-ethylhexyl)phthalate-d4(Surrogate), Particulate", "Bis(2-ethylhexyl)phthalate-d4(Surrogate), Total", "Bisphenol A, Total", "Bisphenol A-d6(Surrogate), Total", "Bispyribac Sodium, Total", "Bivalve CI Mean", "Bivalve CI Mean, Total", "Bivalve CI SE", "Bivalve CI SE, Total", "Bolstar, Total", "Boscalid, Dissolved", "Boscalid, Particulate", "Boscalid, Total", "Bromacil, Dissolved", "Bromacil, Not Recorded", "Bromacil, Total", "Bromo-3,5-dimethylphenyl-N-methylcarbamate, 4-(Surrogate), Dissolved", "Bromo-3,5-dimethylphenyl-N-methylcarbamate, 4-(Surrogate), Total", "Bromobenzene, Total", "Bromochloromethane, Total", "Bromodichloromethane, Total", "Bromofluorobenzene, 4-(Surrogate), Total", "Bromofluorobenzene, 4-, Total", "Bromoform, Total", "Bromomethane, Total", "Bromophenyl Phenyl Ether, 4-, Total", "Bromuconazole, Dissolved", "Bromuconazole, Particulate", "Butachlor, Total", "Butanone, 2-, Total", "Butralin, Dissolved", "Butralin, Particulate", "Butyl Benzyl Phthalate, Dissolved", "Butyl Benzyl Phthalate, Particulate", "Butyl Benzyl Phthalate, Total", "Butyl Benzyl Phthalate-d4(Surrogate), Dissolved", "Butyl Benzyl Phthalate-d4(Surrogate), Particulate", "Butyl Benzyl Phthalate-d4(Surrogate), Total", "Butylate, Dissolved", "Butylate, Particulate", "Butylate, Total", "Butylbenzene, n-, Total", "Butylbenzene, sec-, Total", "Butylbenzene, tert-, Total", "Butyl-N-ethyl-2,6-dinitro-4-(trifluoromethyl)aniline, N-, Not Recorded", "Butyltin as Sn, Total", "Caffeine, Dissolved", "Caffeine, Total", "Caffeine-13C(Surrogate), Dissolved", "Caffeine-13C3(Surrogate), Total", "Captafol, Total", "Captan, Dissolved", "Captan, Particulate", "Captan, Total", "Carbadox, Total", "Carbamazepine, Total", "Carbaryl, Dissolved", "Carbaryl, Not Recorded", "Carbaryl, Particulate", "Carbaryl, Total", "Carbazole(Surrogate), Total", "Carbazole, Total", "Carbendazim, Dissolved", "Carbofuran, Dissolved", "Carbofuran, Not Recorded", "Carbofuran, Particulate", "Carbofuran, Total", "Carbon Tetrachloride, Total", "Carbophenothion, Total", "Carfentrazone Ethyl, Total", "Cefotaxime, Total", "Celestolide, Total", "Chemical Group A, Total", "Chloramben, Total", "Chlorantraniliprole, Dissolved", "Chlorbenside, Total", "Chlordane, cis-(Surrogate), Total", "Chlordane, cis-, Dissolved", "Chlordane, cis-, Particulate", "Chlordane, cis-, Total", "Chlordane, Technical, Total", "Chlordane, Total", "Chlordane, trans-(Surrogate), Dissolved", "Chlordane, trans-(Surrogate), Particulate", "Chlordane, trans-(Surrogate), Total", "Chlordane, trans-, Dissolved", "Chlordane, trans-, Particulate", "Chlordane, trans-, Total", "Chlordene, cis-, Total", "Chlordene, Total", "Chlordene, trans-, Total", "Chlorfenapyr, Not Recorded", "Chlorfenapyr, Total", "Chlorfenvinphos, Total", "Chlorimuron Ethyl, Dissolved", "Chloro-2-methylphenoxy) Butanoic Acid, 4-(4-, Dissolved", "Chloro-3-methylphenol, 4-, Total", "Chloroaniline, 4-, Total", "Chlorobenzene, Total", "Chlorobenzilate, Total", "Chloroethane, Total", "Chloroethyl Vinyl Ether, 2-, Total", "Chloroform, Total", "Chloromethane, Total", "Chloronaphthalene, 2-, Total", "Chloroneb(Surrogate), Total", "Chlorophenol, 2-, Total", "Chlorophenyl Phenyl Ether, 4-, Total", "Chlorophenyl)-N'-methylurea, N-(4-, Dissolved", "Chlorothalonil, Dissolved", "Chlorothalonil, Not Recorded", "Chlorothalonil, Particulate", "Chlorothalonil, Total", "Chlorotoluene, 2-, Total", "Chlorotoluene, 4-, Total", "Chloroxuron(Surrogate), Total", "Chloroxuron, Total", "Chlorpropham, Total", "Chlorpyrifos Methyl(Surrogate), Total", "Chlorpyrifos Methyl, Dissolved", "Chlorpyrifos Methyl, Particulate", "Chlorpyrifos Methyl, Total", "Chlorpyrifos Oxon, Dissolved", "Chlorpyrifos Oxon, Not Recorded", "Chlorpyrifos Oxon, Particulate", "Chlorpyrifos(Surrogate), Total", "Chlorpyrifos, Dissolved", "Chlorpyrifos, Not Recorded", "Chlorpyrifos, Particulate", "Chlorpyrifos, Total", "Chlortetracycline, Total", "Chrysene, Dissolved", "Chrysene, Particulate", "Chrysene, Total", "Chrysene/Triphenylene, Total", "Chrysene-d12(Surrogate), Dissolved", "Chrysene-d12(Surrogate), Particulate", "Chrysene-d12(Surrogate), Total", "Chrysenes, C1-, Dissolved", "Chrysenes, C1-, Particulate", "Chrysenes, C1-, Total", "Chrysenes, C2-, Dissolved", "Chrysenes, C2-, Particulate", "Chrysenes, C2-, Total", "Chrysenes, C3-, Dissolved", "Chrysenes, C3-, Particulate", "Chrysenes, C3-, Total", "Chrysenes, C4-, Dissolved", "Chrysenes, C4-, Particulate", "Chrysenes, C4-, Total", "Cimetidine, Total", "Cimetidine-d3(Surrogate), Total", "Cinerin-1, Dissolved", "Cinerin-1, Total", "Cinerin-2, Dissolved", "Cinerin-2, Total", "Ciodrin, Total", "Ciprofloxacin, Total", "Ciprofloxacin-13C3-N15(Surrogate), Total", "Clarithromycin, Total", "Clinafloxacin, Total", "Clomazone, Dissolved", "Clomazone, Particulate", "Clomazone, Total", "Clonidine, Total", "Clonidine-d4(Surrogate), Total", "Cloxacillin, Total", "Cocaine, Total", "Cocaine-d3(Surrogate), Total", "Codeine, Total", "Codeine-d6(Surrogate), Total", "Coronene, Dissolved", "Coronene, Particulate", "Coronene, Total", "Cotinine, Total", "Cotinine-d3(Surrogate), Total", "Coumaphos, Dissolved", "Coumaphos, Particulate", "Coumaphos, Total", "Cyanazine, Dissolved", "Cyanazine, Not Recorded", "Cyanazine, Total", "Cyantraniliprole, Dissolved", "Cyazofamid, Dissolved", "Cycloate, Dissolved", "Cycloate, Particulate", "Cycloate, Total", "Cyfluthrin, beta-, Total", "Cyfluthrin, total, Dissolved", "Cyfluthrin, total, Particulate", "Cyfluthrin, total, Total", "Cyfluthrin-1, Total", "Cyfluthrin-2, Total", "Cyfluthrin-3, Total", "Cyfluthrin-4, Total", "Cyhalofop-butyl, Dissolved", "Cyhalofop-butyl, Particulate", "Cyhalofop-butyl, Total", "Cyhalothrin, Dissolved", "Cyhalothrin, gamma-, Total", "Cyhalothrin, lambda-1, Total", "Cyhalothrin, lambda-2, Total", "Cyhalothrin, Particulate", "Cyhalothrin, Total", "Cyhalothrin, Total lambda-, Total", "Cymene, p-, Total", "Cymoxanil, Dissolved", "Cypermethrin, Total, Dissolved", "Cypermethrin, Total, Particulate", "Cypermethrin, Total, Total", "Cypermethrin-1, Total", "Cypermethrin-13C6(Surrogate), Total", "Cypermethrin-2, Total", "Cypermethrin-3, Total", "Cypermethrin-4, Total", "Cyproconazole, Dissolved", "Cyproconazole, Particulate", "Cyprodinil, Dissolved", "Cyprodinil, Particulate", "Dacthal, Dissolved", "Dacthal, Particulate", "Dacthal, Total", "DBCE(Surrogate), Total", "DCBP(p,p'), Total", "DDD(o,p')(Surrogate), Total", "DDD(o,p'), Dissolved", "DDD(o,p'), Particulate", "DDD(o,p'), Total", "DDD(o,p')/PCB 118, Total", "DDD(p,p')(Surrogate), Dissolved", "DDD(p,p')(Surrogate), Particulate", "DDD(p,p')(Surrogate), Total", "DDD(p,p'), Dissolved", "DDD(p,p'), Particulate", "DDD(p,p'), Total", "DDD-13C(p,p')(Surrogate), Particulate", "DDE(o,p')(Surrogate), Dissolved", "DDE(o,p')(Surrogate), Particulate", "DDE(o,p')(Surrogate), Total", "DDE(o,p'), Dissolved", "DDE(o,p'), Particulate", "DDE(o,p'), Total", "DDE(p,p')(Surrogate), Dissolved", "DDE(p,p')(Surrogate), Particulate", "DDE(p,p')(Surrogate), Total", "DDE(p,p'), Dissolved", "DDE(p,p'), Particulate", "DDE(p,p'), Total", "DDE(p,p')/PCB 087, Total", "DDMS(p,p'), Total", "DDMU(p,p'), Dissolved", "DDMU(p,p'), Particulate", "DDMU(p,p'), Total", "DDT(o,p')(Surrogate), Dissolved", "DDT(o,p')(Surrogate), Particulate", "DDT(o,p')(Surrogate), Total", "DDT(o,p'), Dissolved", "DDT(o,p'), Particulate", "DDT(o,p'), Total", "DDT(p,p')(Surrogate), Dissolved", "DDT(p,p')(Surrogate), Particulate", "DDT(p,p')(Surrogate), Total", "DDT(p,p'), Dissolved", "DDT(p,p'), Particulate", "DDT(p,p'), Total", "DDT(p,p')/PCB 187, Total", "Decachlorobiphenyl(Surrogate), Total", "Decafluorobiphenyl(Surrogate), Total", "Decalin, C1-, Total", "Decalin, C2-, Total", "Decalin, C3-, Total", "Decalin, C4-, Total", "Decalin, Total", "Decane, 2-phenyl-, Total", "Decane, 3-phenyl-, Total", "Decane, 4-phenyl-, Total", "Decane, 5-phenyl-, Total", "Decane, n-, Total", "Dehydronifedipine, Total", "Deisopropyl-Atrazine, Dissolved", "Deisopropyl-Atrazine, Total", "Delta 13C, Total", "Delta 15N - baseline corrected, Total", "Delta 15N, Total", "Deltamethrin, Dissolved", "Deltamethrin, Not Recorded", "Deltamethrin, Particulate", "Deltamethrin, Total", "Deltamethrin/Tralomethrin, Total", "Demeton, Total, Total", "Demeton-O, Total", "Demeton-s, Total", "Desethyl-Atrazine, Dissolved", "Desethyl-Atrazine, Not Recorded", "Desethyl-Atrazine, Total", "Desethyl-desisopropyl-atrazine, Dissolved", "Desethyl-desisopropyl-atrazine, Total", "Desisopropyl-Atrazine, Dissolved", "Desisopropyl-Atrazine, Not Recorded", "Desisopropyl-Atrazine, Total", "Desmethyldiltiazem, Total", "Desmetryn, Dissolved", "Desmetryn, Total", "Desthio-prothioconazole, Dissolved", "Diaminochlorotriazine (DACT), Not Recorded", "Diazepam, Total", "Diazepam-d5(Surrogate), Total", "Diazinon oxon, Dissolved", "Diazinon oxon, Particulate", "Diazinon(Surrogate), Total", "Diazinon, Dissolved", "Diazinon, Not Recorded", "Diazinon, Particulate", "Diazinon, Total", "Diazoxon, Dissolved", "Diazoxon, Not Recorded", "Diazoxon, Particulate", "Dibenz(a,h)anthracene, C1-, Total", "Dibenz(a,h)anthracene, C2-, Total", "Dibenz(a,h)anthracene, C3-, Total", "Dibenz(a,h)anthracene, Dissolved", "Dibenz(a,h)anthracene, Particulate", "Dibenz(a,h)anthracene, Total", "Dibenz(a,h)anthracene-d14(Surrogate), Dissolved", "Dibenz(a,h)anthracene-d14(Surrogate), Particulate", "Dibenz(a,h)anthracene-d14(Surrogate), Total", "Dibenzofuran, Total", "Dibenzothiophene, Dissolved", "Dibenzothiophene, Particulate", "Dibenzothiophene, Total", "Dibenzothiophene-d8(Surrogate), Dissolved", "Dibenzothiophene-d8(Surrogate), Particulate", "Dibenzothiophene-d8(Surrogate), Total", "Dibenzothiophenes, C1-, Dissolved", "Dibenzothiophenes, C1-, Particulate", "Dibenzothiophenes, C1-, Total", "Dibenzothiophenes, C2-, Dissolved", "Dibenzothiophenes, C2-, Particulate", "Dibenzothiophenes, C2-, Total", "Dibenzothiophenes, C3-, Dissolved", "Dibenzothiophenes, C3-, Particulate", "Dibenzothiophenes, C3-, Total", "Dibromo-3-Chloropropane, 1,2-, Total", "Dibromo-4-hydroxybenzonitrile, 3,5-, Dissolved", "Dibromochloromethane, Total", "Dibromoethane, 1,2-, Total", "Dibromofluoromethane(Surrogate), Total", "Dibromofluoromethane, Total", "Dibromomethane, Total", "Dibromooctafluorobiphenyl(Surrogate), Total", "Dibromooctafluorobiphenyl, 4,4'-(Surrogate), Total", "Dibromooctafluorobiphenyl, 4,4'-(Surrogate)DB-608, Total", "Dibromooctafluorobiphenyl, 4,4'-(Surrogate)HP-5, Total", "Dibromooctafluorobiphenyl, 4-4'-(Surrogate), Total", "Dibutylchlorendate(Surrogate), Total", "Dibutyltin as Sn, Total", "Dicamba, Dissolved", "Dicamba, Not Recorded", "Dicamba, Total", "Dichlofenthion(Surrogate), Total", "Dichlofenthion, Total", "Dichlone, Total", "Dichloro-2 butene, cis 1,4-, Total", "Dichloroacetate(Surrogate), Dissolved", "Dichloroacetate(Surrogate), Total", "Dichloroaniline, 3,5-, Dissolved", "Dichloroaniline, 3,5-, Particulate", "Dichlorobenzene, 1,2-, Total", "Dichlorobenzene, 1,3-, Total", "Dichlorobenzene, 1,4-, Total", "Dichlorobenzene-d4, 1,2-(Surrogate), Total", "Dichlorobenzene-d4, 1,4-(Surrogate), Total", "Dichlorobenzidine, 3,3'-, Total", "Dichlorobenzoic Acid, 3,5-, Total", "Dichlorobenzophenone(p,p'), Total", "Dichlorodifluoromethane, Total", "Dichloroethane, 1,1-, Total", "Dichloroethane, 1,2-, Total", "Dichloroethane-d4, 1,2-(Surrogate), Total", "Dichloroethylene, 1,1-, Total", "Dichloroethylene, cis 1,2-, Total", "Dichloroethylene, Total 1,2-, Total", "Dichloroethylene, trans 1,2-, Total", "Dichlorophenol, 2,4-, Total", "Dichlorophenol, 2,6-, Total", "Dichlorophenoxyacetic Acid, 2,3-(Surrogate), Total", "Dichlorophenoxyacetic Acid, 2,4-, Dissolved", "Dichlorophenoxyacetic Acid, 2,4-, Not Recorded", "Dichlorophenoxyacetic Acid, 2,4-, Total", "Dichlorophenoxybutyric Acid Methyl Ester, 2,4-, Dissolved", "Dichlorophenoxybutyric Acid, 2,4-, Dissolved", "Dichlorophenoxybutyric Acid, 2,4-, Total", "Dichlorophenylacetic Acid, 2,4- (Surrogate), Total", "Dichloroprop, Dissolved", "Dichloroprop, Total", "Dichloropropane, 1,2-, Total", "Dichloropropane, 1,3-, Total", "Dichloropropane, 2,2-, Total", "Dichloropropene, 1,1-, Total", "Dichloropropene, cis 1,3-, Total", "Dichloropropene, Total 1,3-, Total", "Dichloropropene, trans 1,3-, Total", "Dichloropropionic Acid, 2,2-, Total", "Dichloro-pyridine-2-carboxylic Acid, 3,6-, Dissolved", "Dichlorotrifluoroethane, Total", "Dichlorotrifluoromethane, Total", "Dichlorvos, Not Recorded", "Dichlorvos, Total", "Dichrotophos, Total", "Dicofol, Total", "Dicrotophos, Total", "Dieldrin(Surrogate), Dissolved", "Dieldrin(Surrogate), Particulate", "Dieldrin(Surrogate), Total", "Dieldrin, Dissolved", "Dieldrin, Particulate", "Dieldrin, Total", "Diesel Fuel, Total", "Diethatyl-Ethyl, Total", "Diethyl phthalate, Total", "Diethyl-3-methyl-benzamide, N,N-, Total", "Diethyl-3-methyl-benzamide-d7, N,N-(Surrogate), Total", "Diethylstilbestrol, Total", "Difenoconazole, Dissolved", "Difenoconazole, Particulate", "Diflubenzuron, Total", "Difluoro-2,2',3,4,4'-Pentabromodiphenyl Ether, 5,6-(Surrogate), Total", "Difluoro-2,2’,3,3’,4,5,5’,6’-Octabromodiphenyl Ether 4’,6-(Surrogate), Total", "Digoxigenin, Total", "Digoxin, Total", "Diisopropyl Ether, Total", "Diltiazem, Total", "Dimethoate, Not Recorded", "Dimethoate, Total", "Dimethomorph, Dissolved", "Dimethomorph, Particulate", "Dimethyl phthalate, Total", "Dimethyl-2-nitrobenzene, 1,3-(Surrogate), Total", "Dimethylarsinic Acid, Total", "Dimethylchrysene, 5,9-, Dissolved", "Dimethylchrysene, 5,9-, Particulate", "Dimethylchrysene, 5,9-, Total", "Dimethyldibenzothiophene, 2,4-, Dissolved", "Dimethyldibenzothiophene, 2,4-, Particulate", "Dimethyldibenzothiophene, 2,4-, Total", "Dimethylfluorene, 1,7-, Dissolved", "Dimethylfluorene, 1,7-, Particulate", "Dimethylfluorene, 1,7-, Total", "Dimethylnaphthalene, 1,2-, Dissolved", "Dimethylnaphthalene, 1,2-, Particulate", "Dimethylnaphthalene, 1,2-, Total", "Dimethylnaphthalene, 2,6-(Surrogate), Dissolved", "Dimethylnaphthalene, 2,6-(Surrogate), Particulate", "Dimethylnaphthalene, 2,6-(Surrogate), Total", "Dimethylnaphthalene, 2,6-, Dissolved", "Dimethylnaphthalene, 2,6-, Particulate", "Dimethylnaphthalene, 2,6-, Total", "Dimethylnaphthalene-d12, 2,6-(Surrogate), Dissolved", "Dimethylnaphthalene-d12, 2,6-(Surrogate), Particulate", "Dimethylnaphthalene-d12, 2,6-(Surrogate), Total", "Dimethylphenanthrene, 1,5/1,7-, Dissolved", "Dimethylphenanthrene, 1,5/1,7-, Particulate", "Dimethylphenanthrene, 1,5/1,7-, Total", "Dimethylphenanthrene, 1,7-, Dissolved", "Dimethylphenanthrene, 1,7-, Particulate", "Dimethylphenanthrene, 1,7-, Total", "Dimethylphenanthrene, 3,6-, Dissolved", "Dimethylphenanthrene, 3,6-, Particulate", "Dimethylphenanthrene, 3,6-, Total", "Dimethylphenol, 2,4-, Total", "Dimethylxanthine, 1,7-, Total", "Di-n-butyl Phthalate, Dissolved", "Di-n-butyl Phthalate, Particulate", "Di-n-butyl Phthalate, Total", "Di-n-butyl Phthalate-d4(Surrogate), Dissolved", "Di-n-butyl Phthalate-d4(Surrogate), Particulate", "Di-n-butyl Phthalate-d4(Surrogate), Total", "Dinitro-2-methylphenol, 4,6-, Total", "Dinitrophenol, 2,4-, Total", "Dinitrotoluene, 2,4-, Total", "Dinitrotoluene, 2,6-, Total", "Di-n-octyl Phthalate, Total", "Dinoseb, Dissolved", "Dinoseb, Total", "Dinotefuran, Dissolved", "Di-n-propylnitrosamine, Total", "Dioxathion, Total", "Diphenamid(Surrogate), Total", "Diphenamid, Dissolved", "Diphenamid, Total", "Diphenhydramine, Total", "Diphenyl Ether, Total", "Diphenylamine, Total", "Diphenylhydrazine, 1,2-, Total", "Diphenylphthalate(Surrogate), Total", "Dipropetryn, Dissolved", "Dipropetryn, Total", "Diquat, Total", "Disulfoton Sulfone, Total", "Disulfoton, Not Recorded", "Disulfoton, Total", "Dithiopyr, Dissolved", "Dithiopyr, Particulate", "Diuron, Dissolved", "Diuron, Not Recorded", "Diuron, Total", "Docosahexaenoic Acid, Total", "Docosane, n-, Total", "Docosapentaenoic Acid, Total", "Dodecane, 2-phenyl-, Total", "Dodecane, 3-phenyl-, Total", "Dodecane, 4-phenyl-, Total", "Dodecane, 5-phenyl-, Total", "Dodecane, 6-phenyl-, Total", "Dodecane, n-, Total", "Doxycycline, Total", "Eicosane, n-, Total", "Eicosapentaenoate, Total", "Enalapril, Total", "Enalapril-d5(Surrogate), Total", "Endosulfan I(Surrogate), Dissolved", "Endosulfan I(Surrogate), Particulate", "Endosulfan I(Surrogate), Total", "Endosulfan I, Dissolved", "Endosulfan I, Particulate", "Endosulfan I, Total", "Endosulfan I-d4(Surrogate), Dissolved", "Endosulfan I-d4(Surrogate), Particulate", "Endosulfan I-d4(Surrogate), Total", "Endosulfan II(Surrogate), Dissolved", "Endosulfan II(Surrogate), Particulate", "Endosulfan II(Surrogate), Total", "Endosulfan II, Dissolved", "Endosulfan II, Not Recorded", "Endosulfan II, Particulate", "Endosulfan II, Total", "Endosulfan II-d4(Surrogate), Dissolved", "Endosulfan II-d4(Surrogate), Particulate", "Endosulfan II-d4(Surrogate), Total", "Endosulfan Sulfate, Dissolved", "Endosulfan Sulfate, Not Recorded", "Endosulfan Sulfate, Particulate", "Endosulfan Sulfate, Total", "Endrin Aldehyde(Surrogate), Total", "Endrin Aldehyde, Total", "Endrin Ketone, Total", "Endrin Ketone-13C12(Surrogate), Total", "Endrin(Surrogate), Dissolved", "Endrin(Surrogate), Particulate", "Endrin(Surrogate), Total", "Endrin, Dissolved", "Endrin, Particulate", "Endrin, Total", "Endrin-13C12(Surrogate), Total", "Enrofloxacin, Total", "EPN(Surrogate), Total", "EPN, Total", "EPTC(Surrogate), Total", "EPTC, Dissolved", "EPTC, Particulate", "EPTC, Total", "Erythromycin-H2O, Total", "Erythromycin-H2O-13C2(Surrogate), Total", "Esfenvalerate, Dissolved", "Esfenvalerate, Not Recorded", "Esfenvalerate, Particulate", "Esfenvalerate, Total", "Esfenvalerate/Fenvalerate, Total, Total", "Esfenvalerate/Fenvalerate-1, Total", "Esfenvalerate/Fenvalerate-2, Total", "Esfenvalerate-d6, Total(Surrogate), Total", "Esfenvalerate-d6-1(Surrogate), Total", "Esfenvalerate-d6-2(Surrogate), Total", "Estradiol, 17beta-, Total", "Ethaboxam, Dissolved", "Ethafluralin, Total", "Ethalfluralin, Dissolved", "Ethalfluralin, Not Recorded", "Ethalfluralin, Particulate", "Ethalfluralin, Total", "Ethion(Surrogate), Total", "Ethion, Total", "Ethofenprox, Dissolved", "Ethofenprox, Particulate", "Ethofenprox, Total", "Ethoprop, Not Recorded", "Ethoprop, Total", "Ethyl Ether, Total", "Ethyl Tert-butyl Ether, Total", "Ethylbenzene, Total", "Ethyl-perfluorooctanesulfonamide, N-, Total", "Ethyl-perfluorooctanesulfonamidoethanol, N-, Total", "Famoxadone, Dissolved", "Famoxadone, Particulate", "Famphur, Total", "Fenamidone, Dissolved", "Fenamidone, Particulate", "Fenamiphos, Not Recorded", "Fenamiphos, Total", "Fenarimol, Dissolved", "Fenarimol, Particulate", "Fenbuconazole, Dissolved", "Fenbuconazole, Particulate", "Fenchlorphos, Total", "Fenhexamid, Dissolved", "Fenhexamid, Particulate", "Fenitrothion, Total", "Fenoxycarb, Not Recorded", "Fenpropathrin, Dissolved", "Fenpropathrin, Not Recorded", "Fenpropathrin, Particulate", "Fenpropathrin, Total", "Fenpropathrin-d6(Surrogate), Total", "Fenpyroximate, Dissolved", "Fenpyroximate, Particulate", "Fensulfothion, Total", "Fenthion, Dissolved", "Fenthion, Particulate", "Fenthion, Total", "Fenuron, Dissolved", "Fenuron, Total", "Fenvalerate, Total", "Fipronil Amide, Dissolved", "Fipronil Amide, Not Recorded", "Fipronil Amide, Total", "Fipronil Desulfinyl Amide, Dissolved", "Fipronil Desulfinyl Amide, Not Recorded", "Fipronil Desulfinyl Amide, Particulate", "Fipronil Desulfinyl Amide, Total", "Fipronil Desulfinyl, Dissolved", "Fipronil Desulfinyl, Not Recorded", "Fipronil Desulfinyl, Particulate", "Fipronil Desulfinyl, Total", "Fipronil Sulfide, Dissolved", "Fipronil Sulfide, Not Recorded", "Fipronil Sulfide, Particulate", "Fipronil Sulfide, Total", "Fipronil Sulfone, Dissolved", "Fipronil Sulfone, Not Recorded", "Fipronil Sulfone, Particulate", "Fipronil Sulfone, Total", "Fipronil, Dissolved", "Fipronil, Not Recorded", "Fipronil, Particulate", "Fipronil, Total", "Fipronil-C13(Surrogate), Dissolved", "Fipronil-C13(Surrogate), Particulate", "Flonicamid, Dissolved", "Fluazinam, Dissolved", "Fluazinam, Particulate", "Flucythrinate, Total", "Fludioxonil, Dissolved", "Fludioxonil, Particulate", "Flufenacet, Dissolved", "Flufenacet, Particulate", "Flumequine, Total", "Flumetralin, Dissolved", "Flumetralin, Particulate", "Flumetsulam, Dissolved", "Fluocinonide, Total", "Fluometuron, Dissolved", "Fluometuron, Total", "Fluopicolide, Dissolved", "Fluopicolide, Particulate", "Fluopyram, Dissolved", "Fluopyram, Particulate", "Fluoranthene, Dissolved", "Fluoranthene, Particulate", "Fluoranthene, Total", "Fluoranthene/Pyrenes, C1-, Dissolved", "Fluoranthene/Pyrenes, C1-, Particulate", "Fluoranthene/Pyrenes, C1-, Total", "Fluoranthene-d10(Surrogate), Dissolved", "Fluoranthene-d10(Surrogate), Particulate", "Fluoranthene-d10(Surrogate), Total", "Fluoranthenes/Pyrenes, C2-, Total", "Fluoranthenes/Pyrenes, C3-, Total", "Fluorene, Dissolved", "Fluorene, Particulate", "Fluorene, Total", "Fluorene-d10(Surrogate), Total", "Fluorenes, C1-, Dissolved", "Fluorenes, C1-, Particulate", "Fluorenes, C1-, Total", "Fluorenes, C2-, Dissolved", "Fluorenes, C2-, Particulate", "Fluorenes, C2-, Total", "Fluorenes, C3-, Dissolved", "Fluorenes, C3-, Particulate", "Fluorenes, C3-, Total", "Fluoro-2,3',6-Tribromodiphenyl Ether, 4'-(Surrogate), Total", "Fluorobiphenyl, 2-(Surrogate), Total", "Fluorobiphenyl, 2-, Total", "Fluorophenol, 2-(Surrogate), Total", "Fluorophenol, 2-, Total", "Fluoxastrobin, Dissolved", "Fluoxastrobin, Particulate", "Fluoxetine, Total", "Fluoxetine-d5(Surrogate), Total", "Fluridone(Surrogate), Dissolved", "Fluridone(Surrogate), Total", "Fluridone, Dissolved", "Fluridone, Total", "Flusilazole, Dissolved", "Flusilazole, Particulate", "Fluticasone Propionate, Total", "Flutolanil, Dissolved", "Flutolanil, Particulate", "Flutolanil, Total", "Flutriafol, Dissolved", "Flutriafol, Particulate", "Fluvalinate, Total", "Fluxapyroxad, Dissolved", "Fluxapyroxad, Particulate", "Folpet, Total", "Fonofos, Not Recorded", "Fonofos, Total", "Formate(Surrogate), Dissolved", "Furosemide, Total", "Galaxolide, Total", "Gasoline, Total", "Gemfibrozil, Total", "Gemfibrozil-d6(Surrogate), Total", "Glipizide, Total", "Glipizide-d11(Surrogate), Total", "Glyburide, Total", "Glyburide-d3(Surrogate), Total", "Glyphosate, Dissolved", "Glyphosate, Not Recorded", "Glyphosate, Total", "Halosulfuron Methyl, Total", "HCH, alpha-(Surrogate), Total", "HCH, alpha-, Dissolved", "HCH, alpha-, Particulate", "HCH, alpha-, Total", "HCH, beta-(Surrogate), Dissolved", "HCH, beta-(Surrogate), Particulate", "HCH, beta-(Surrogate), Total", "HCH, beta-, Dissolved", "HCH, beta-, Particulate", "HCH, beta-, Total", "HCH, delta-(Surrogate), Dissolved", "HCH, delta-(Surrogate), Particulate", "HCH, delta-(Surrogate), Total", "HCH, delta-, Dissolved", "HCH, delta-, Particulate", "HCH, delta-, Total", "HCH, gamma-(Surrogate), Dissolved", "HCH, gamma-(Surrogate), Particulate", "HCH, gamma-(Surrogate), Total", "HCH, gamma-, Dissolved", "HCH, gamma-, Particulate", "HCH, gamma-, Total", "HCH, gamma-/PCB 015/18, Total", "HCH-d6, gamma-(Surrogate), Total", "Heptachlor Epoxide(Surrogate), Dissolved", "Heptachlor Epoxide(Surrogate), Particulate", "Heptachlor Epoxide(Surrogate), Total", "Heptachlor Epoxide, Dissolved", "Heptachlor Epoxide, Particulate", "Heptachlor Epoxide, Total", "Heptachlor Epoxide/Oxychlordane, Dissolved", "Heptachlor Epoxide/Oxychlordane, Particulate", "Heptachlor Epoxide/Oxychlordane, Total", "Heptachlor Epoxide-13C10(Surrogate), Total", "Heptachlor(Surrogate), Dissolved", "Heptachlor(Surrogate), Particulate", "Heptachlor(Surrogate), Total", "Heptachlor, Dissolved", "Heptachlor, Particulate", "Heptachlor, Total", "Heptachlor-13C10(Surrogate), Total", "Heptachlorobenzene, Total", "Hexachlorobenzene(Surrogate), Dissolved", "Hexachlorobenzene(Surrogate), Particulate", "Hexachlorobenzene(Surrogate), Total", "Hexachlorobenzene, Dissolved", "Hexachlorobenzene, Particulate", "Hexachlorobenzene, Total", "Hexachlorobenzene-13C6(Surrogate), Total", "Hexachlorobutadiene, Dissolved", "Hexachlorobutadiene, Particulate", "Hexachlorobutadiene, Total", "Hexachlorocyclopentadiene, Total", "Hexachloroethane, Total", "Hexacosane, n-, Total", "Hexadecane, n-, Total", "Hexanone, 2-, Total", "Hexazinone, Dissolved", "Hexazinone, Not Recorded", "Hexazinone, Particulate", "Hexazinone, Total", "Hopane, C29-, Total", "Hopane, C30-, Total", "HPCDD, 1,2,3,4,6,7,8- (TEQ ND=0), Total", "HPCDD, 1,2,3,4,6,7,8- (TEQ ND=1/2 DL), Total", "HpCDD, 1,2,3,4,6,7,8-(Surrogate), Total", "HpCDD, 1,2,3,4,6,7,8-, Dissolved", "HpCDD, 1,2,3,4,6,7,8-, Particulate", "HpCDD, 1,2,3,4,6,7,8-, Total", "HpCDD-13C, 1,2,3,4,6,7,8-(Surrogate), Dissolved", "HpCDD-13C, 1,2,3,4,6,7,8-(Surrogate), Particulate", "HpCDD-13C, 1,2,3,4,6,7,8-(Surrogate), Total", "HPCDF, 1,2,3,4,6,7,8- (TEQ ND=0), Total", "HPCDF, 1,2,3,4,6,7,8- (TEQ ND=1/2 DL), Total", "HpCDF, 1,2,3,4,6,7,8-(Surrogate), Total", "HpCDF, 1,2,3,4,6,7,8-, Dissolved", "HpCDF, 1,2,3,4,6,7,8-, Particulate", "HpCDF, 1,2,3,4,6,7,8-, Total", "HpCDF, 1,2,3,4,6,7,8,9-(Surrogate), Total", "HPCDF, 1,2,3,4,7,8,9- (TEQ ND=0), Total", "HPCDF, 1,2,3,4,7,8,9- (TEQ ND=1/2 DL), Total", "HpCDF, 1,2,3,4,7,8,9-(Surrogate), Total", "HpCDF, 1,2,3,4,7,8,9-, Dissolved", "HpCDF, 1,2,3,4,7,8,9-, Particulate", "HpCDF, 1,2,3,4,7,8,9-, Total", "HpCDF-13C, 1,2,3,4,6,7,8-(Surrogate), Dissolved", "HpCDF-13C, 1,2,3,4,6,7,8-(Surrogate), Particulate", "HpCDF-13C, 1,2,3,4,6,7,8-(Surrogate), Total", "HpCDF-13C, 1,2,3,4,7,8,9-(Surrogate), Dissolved", "HpCDF-13C, 1,2,3,4,7,8,9-(Surrogate), Particulate", "HpCDF-13C, 1,2,3,4,7,8,9-(Surrogate), Total", "HXCDD, 1,2,3,4,7,8- (TEQ ND=0), Total", "HXCDD, 1,2,3,4,7,8- (TEQ ND=1/2 DL), Total", "HxCDD, 1,2,3,4,7,8-(Surrogate), Total", "HxCDD, 1,2,3,4,7,8-, Dissolved", "HxCDD, 1,2,3,4,7,8-, Particulate", "HxCDD, 1,2,3,4,7,8-, Total", "HXCDD, 1,2,3,6,7,8- (TEQ ND=0), Total", "HXCDD, 1,2,3,6,7,8- (TEQ ND=1/2 DL), Total", "HxCDD, 1,2,3,6,7,8-(Surrogate), Total", "HxCDD, 1,2,3,6,7,8-, Dissolved", "HxCDD, 1,2,3,6,7,8-, Particulate", "HxCDD, 1,2,3,6,7,8-, Total", "HXCDD, 1,2,3,7,8,9- (TEQ ND=0), Total", "HXCDD, 1,2,3,7,8,9- (TEQ ND=1/2 DL), Total", "HxCDD, 1,2,3,7,8,9-, Dissolved", "HxCDD, 1,2,3,7,8,9-, Particulate", "HxCDD, 1,2,3,7,8,9-, Total", "HxCDD-13C, 1,2,3,4,7,8-(Surrogate), Dissolved", "HxCDD-13C, 1,2,3,4,7,8-(Surrogate), Particulate", "HxCDD-13C, 1,2,3,4,7,8-(Surrogate), Total", "HxCDD-13C, 1,2,3,6,7,8-(Surrogate), Dissolved", "HxCDD-13C, 1,2,3,6,7,8-(Surrogate), Particulate", "HxCDD-13C, 1,2,3,6,7,8-(Surrogate), Total", "HXCDF, 1,2,3,4,7,8- (TEQ ND=0), Total", "HXCDF, 1,2,3,4,7,8- (TEQ ND=1/2 DL), Total", "HxCDF, 1,2,3,4,7,8-(Surrogate), Total", "HxCDF, 1,2,3,4,7,8-, Dissolved", "HxCDF, 1,2,3,4,7,8-, Particulate", "HxCDF, 1,2,3,4,7,8-, Total", "HXCDF, 1,2,3,6,7,8- (TEQ ND=0), Total", "HXCDF, 1,2,3,6,7,8- (TEQ ND=1/2 DL), Total", "HxCDF, 1,2,3,6,7,8-(Surrogate), Total", "HxCDF, 1,2,3,6,7,8-, Dissolved", "HxCDF, 1,2,3,6,7,8-, Particulate", "HxCDF, 1,2,3,6,7,8-, Total", "HXCDF, 1,2,3,7,8,9- (TEQ ND=0), Total", "HXCDF, 1,2,3,7,8,9- (TEQ ND=1/2 DL), Total", "HxCDF, 1,2,3,7,8,9-(Surrogate), Total", "HxCDF, 1,2,3,7,8,9-, Dissolved", "HxCDF, 1,2,3,7,8,9-, Particulate", "HxCDF, 1,2,3,7,8,9-, Total", "HXCDF, 2,3,4,6,7,8- (TEQ ND=0), Total", "HXCDF, 2,3,4,6,7,8- (TEQ ND=1/2 DL), Total", "HXCDF, 2,3,4,6,7,8-(Surrogate), Total", "HxCDF, 2,3,4,6,7,8-, Dissolved", "HxCDF, 2,3,4,6,7,8-, Particulate", "HxCDF, 2,3,4,6,7,8-, Total", "HxCDF-13C, 1,2,3,4,7,8-(Surrogate), Dissolved", "HxCDF-13C, 1,2,3,4,7,8-(Surrogate), Particulate", "HxCDF-13C, 1,2,3,4,7,8-(Surrogate), Total", "HxCDF-13C, 1,2,3,6,7,8-(Surrogate), Dissolved", "HxCDF-13C, 1,2,3,6,7,8-(Surrogate), Particulate", "HxCDF-13C, 1,2,3,6,7,8-(Surrogate), Total", "HxCDF-13C, 1,2,3,7,8,9-(Surrogate), Dissolved", "HxCDF-13C, 1,2,3,7,8,9-(Surrogate), Particulate", "HxCDF-13C, 1,2,3,7,8,9-(Surrogate), Total", "HxCDF-13C, 2,3,4,6,7,8-(Surrogate), Dissolved", "HxCDF-13C, 2,3,4,6,7,8-(Surrogate), Particulate", "HxCDF-13C, 2,3,4,6,7,8-(Surrogate), Total", "Hydramethylnon, Not Recorded", "Hydrochlorothiazide, Total", "Hydrocodone, Total", "Hydrocodone-d3(Surrogate), Total", "Hydrocortisone, Total", "Hydrocortisone-d4(Surrogate), Total", "Hydroxy-amitriptyline, 10-, Total", "Hydroxyatrazine, 2-, Dissolved", "Hydroxyatrazine, 2-, Total", "Hydroxycarbofuran, 3- , Dissolved", "Hydroxycarbofuran, 3- , Not Recorded", "Hydroxycarbofuran, 3- , Total", "Hydroxy-ibuprofen, 2-, Total", "Hydroxypropanal, 3-, Total", "Ibuprofen, Total", "Ibuprofen-13C3(Surrogate), Total", "Imazalil, Dissolved", "Imazalil, Particulate", "Imazalil, Total", "Imazaquin, Dissolved", "Imazethapyr, Dissolved", "Imidacloprid guanidine olefin, Not Recorded", "Imidacloprid guanidine, Not Recorded", "Imidacloprid olefin, Not Recorded", "Imidacloprid urea, Not Recorded", "Imidacloprid, Dissolved", "Imidacloprid, Not Recorded", "Imidacloprid, Total", "Imidacloprid-d4(Surrogate), Dissolved", "Indeno(1,2,3-c,d)pyrene, Dissolved", "Indeno(1,2,3-c,d)pyrene, Particulate", "Indeno(1,2,3-c,d)pyrene, Total", "Indeno(1,2,3-c,d)pyrene-d12(Surrogate), Dissolved", "Indeno(1,2,3-c,d)pyrene-d12(Surrogate), Particulate", "Indeno(1,2,3-c,d)pyrene-d12(Surrogate), Total", "Indoxacarb, Dissolved", "Indoxacarb, Particulate", "Ipconazole, Dissolved", "Ipconazole, Particulate", "Iprodione, Dissolved", "Iprodione, Particulate", "Iprodione, Total", "Isodrin, Total", "Isodrin-13C12(Surrogate), Total", "Isofenphos, Total", "Isophorone, Total", "Isopropylbenzene, Total", "Isopropyltoluene, p-, Total", "Isoxaben(Surrogate), Total", "Isoxaben, Total", "Jasmolin-1, Dissolved", "Jasmolin-1, Total", "Jasmolin-2, Dissolved", "Jasmolin-2, Total", "Kepone, Total", "Ketocarbofuran, 3-, Dissolved", "Kresoxim-methyl, Dissolved", "Kresoxim-methyl, Not Recorded", "Kresoxim-methyl, Particulate", "Kresoxim-methyl, Total", "Leptophos, Total", "Lincomycin, Total", "Linuron, Dissolved", "Linuron, Total", "Lipid, Total", "Lomefloxacin, Total", "Malachite Green, Not Recorded", "Malaoxon, Dissolved", "Malaoxon, Not Recorded", "Malaoxon, Particulate", "Malathion, Dissolved", "Malathion, Not Recorded", "Malathion, Particulate", "Malathion, Total", "Mandipropamid, Dissolved", "MCPA, dimethylamine salt, Not Recorded", "MCPA, Dissolved", "MCPA, Not Recorded", "MCPA, Total", "MCPP, Total", "Meprobamate, Total", "Merphos, Total", "Metalaxyl, Dissolved", "Metalaxyl, Particulate", "Metalaxyl, Total", "Metconazole, Dissolved", "Metconazole, Particulate", "Metconazole, Total", "Metformin, Total", "Metformin-d6(Surrogate), Total", "Methamidophos, Not Recorded", "Methamidophos, Total", "Methidathion oxon, Not Recorded", "Methidathion, Dissolved", "Methidathion, Not Recorded", "Methidathion, Particulate", "Methidathion, Total", "Methiocarb sulfone, Not Recorded", "Methiocarb sulfoxide, Not Recorded", "Methiocarb, Dissolved", "Methiocarb, Not Recorded", "Methiocarb, Total", "Methomyl, Dissolved", "Methomyl, Not Recorded", "Methomyl, Total", "Methoprene, Dissolved", "Methoprene, Particulate", "Methoprene, Total", "Methoxychlor(Surrogate), Total", "Methoxychlor, Dissolved", "Methoxychlor, Particulate", "Methoxychlor, Total", "Methoxychlor-d6(Surrogate), Total", "Methoxyfenozide, Dissolved", "Methoxyfenozide, Not Recorded", "Methoxy-methylsulfanylphosphoryl acetamide, N-, Not Recorded", "Methyl (3,4-dichlorophenyl)carbamate, Total", "Methyl 3-Amino-2,5-dichlorobenzoate, Dissolved", "Methyl paraoxon, Not Recorded", "Methyl Tert-butyl Ether, Total", "Methyl-2-pentanone, 4-, Total", "Methylanthracene, 2-, Dissolved", "Methylanthracene, 2-, Particulate", "Methylanthracene, 2-, Total", "Methylanthracene, Dissolved", "Methylanthracene, Particulate", "Methylanthracene, Total", "Methylbenzo(a)pyrene, 7-, Total", "Methylchrysene, 1-, Dissolved", "Methylchrysene, 1-, Particulate", "Methylchrysene, 1-, Total", "Methylchrysene, 5/6-, Dissolved", "Methylchrysene, 5/6-, Particulate", "Methylchrysene, 5/6-, Total", "Methyldibenzothiophene, 2-, Dissolved", "Methyldibenzothiophene, 2-, Particulate", "Methyldibenzothiophene, 2-, Total", "Methyldibenzothiophene, 4-, Total", "Methyldibenzothiophenes, 2/3-, Dissolved", "Methyldibenzothiophenes, 2/3-, Particulate", "Methyldibenzothiophenes, 2/3-, Total", "Methylene Chloride, Total", "Methylenebis(2-chloroaniline), 4,4'-, Total", "Methylfluoranthene, 2-, Total", "Methylfluoranthene, 3-, Dissolved", "Methylfluoranthene, 3-, Particulate", "Methylfluoranthene, 3-, Total", "Methylfluorene, 1-, Total", "Methylfluorene, 2-, Dissolved", "Methylfluorene, 2-, Particulate", "Methylfluorene, 2-, Total", "Methylnaphthalene, 1-, Dissolved", "Methylnaphthalene, 1-, Particulate", "Methylnaphthalene, 1-, Total", "Methylnaphthalene, 2-, Dissolved", "Methylnaphthalene, 2-, Particulate", "Methylnaphthalene, 2-, Total", "Methylnaphthalene-d10, 2-(Surrogate), Dissolved", "Methylnaphthalene-d10, 2-(Surrogate), Particulate", "Methylnaphthalene-d10, 2-(Surrogate), Total", "Methyl-perfluorooctanesulfonamide, N-, Total", "Methyl-perfluorooctanesulfonamidoethanol, N-, Total", "Methyl-perfluorooctanesulfonamidoethanol-d7, N-(Surrogate), Total", "Methylphenanthrene, 1-, Dissolved", "Methylphenanthrene, 1-, Particulate", "Methylphenanthrene, 1-, Total", "Methylphenanthrene, 2-, Dissolved", "Methylphenanthrene, 2-, Particulate", "Methylphenanthrene, 2-, Total", "Methylphenanthrene, 3-, Total", "Methylphenanthrene, 3/4-, Total", "Methylphenanthrene-d10, 2-(Surrogate), Total", "Methylphenol, 2-, Total", "Methylphenol, 3-, Total", "Methylphenol, 3/4-, Total", "Methylphenol, 4-, Total", "Methylprednisolone, Total", "Methylprednisolone-d2(Surrogate), Total", "Methylpyridine, 2-, Total", "Metolachlor ethanesulfonic acid, Not Recorded", "Metolachlor oxanilic acid, Not Recorded", "Metolachlor, Dissolved", "Metolachlor, Not Recorded", "Metolachlor, Particulate", "Metolachlor, Total", "Metoprolol, Total", "Metoprolol-d7(Surrogate), Total", "Metribuzin, Not Recorded", "Metribuzin, Total", "Metsulfuron Methyl, Dissolved", "Mevinphos, Total", "Mexacarbate, Total", "Miconazole, Total", "Mirex(Surrogate), Dissolved", "Mirex(Surrogate), Particulate", "Mirex(Surrogate), Total", "Mirex, Dissolved", "Mirex, Particulate", "Mirex, Total", "Mirex-13C10(Surrogate), Total", "Moisture, Total", "Molinate, Dissolved", "Molinate, Not Recorded", "Molinate, Particulate", "Molinate, Total", "Monobutyltin as Sn, Total", "Monocrotophos, Total", "Monuron, Total", "Motor Oil, Total", "Musk Ambrette, Total", "Musk Ketone, Total", "Musk Moskene, Total", "Musk Xylene, Total", "Myclobutanil, Dissolved", "Myclobutanil, Particulate", "Myclobutanil, Total", "N,N-Diethyl-3-methyl-benzamide-d7(Surrogate), Total", "Naled, Total", "Naphthalene, Dissolved", "Naphthalene, Particulate", "Naphthalene, Total", "Naphthalene-d8(Surrogate), Dissolved", "Naphthalene-d8(Surrogate), Particulate", "Naphthalene-d8(Surrogate), Total", "Naphthalenes, C1-, Dissolved", "Naphthalenes, C1-, Particulate", "Naphthalenes, C1-, Total", "Naphthalenes, C2-, Dissolved", "Naphthalenes, C2-, Particulate", "Naphthalenes, C2-, Total", "Naphthalenes, C3-, Dissolved", "Naphthalenes, C3-, Particulate", "Naphthalenes, C3-, Total", "Naphthalenes, C4-, Dissolved", "Naphthalenes, C4-, Particulate", "Naphthalenes, C4-, Total", "Naphthobenzothiophene, C1-, Total", "Naphthobenzothiophene, C2-, Total", "Naphthobenzothiophene, C3-, Total", "Naphthobenzothiophene, Total", "Napropamide, Dissolved", "Napropamide, Particulate", "Napropamide, Total", "Naproxen, Total", "Naproxen-d3-13C(Surrogate), Total", "Neburon, Dissolved", "Neburon, Total", "Nicosulfuron, Dissolved", "Nitroaniline, 2-, Total", "Nitroaniline, 3-, Total", "Nitroaniline, 4-, Total", "Nitrobenzene, Total", "Nitrobenzene-d5(Surrogate), Total", "Nitrophenol, 2-, Total", "Nitrophenol, 4-, Total", "Nitrosodiethylamine, N-, Total", "Nitrosodimethylamine, N-, Total", "Nitrosodimethylamine-d6, N-(Surrogate), Total", "Nitrosodi-n-propylamine, N-, Total", "Nitrosodiphenylamine, N-, Total", "Nitrosomethylethylamine, N-, Total", "Nonachlor, cis-(Surrogate), Dissolved", "Nonachlor, cis-(Surrogate), Particulate", "Nonachlor, cis-(Surrogate), Total", "Nonachlor, cis-, Dissolved", "Nonachlor, cis-, Particulate", "Nonachlor, cis-, Total", "Nonachlor, trans-(Surrogate), Dissolved", "Nonachlor, trans-(Surrogate), Particulate", "Nonachlor, trans-(Surrogate), Total", "Nonachlor, trans-, Dissolved", "Nonachlor, trans-, Particulate", "Nonachlor, trans-, Total", "Nonane(Surrogate), Total", "Nonylphenol Diethoxylate, 4-, Total", "Nonylphenol Diethoxylate-13C6, 4-(Surrogate), Total", "Nonylphenol Monoethoxylate, 4-, Total", "Nonylphenol Monoethoxylate-13C6, 4-(Surrogate), Total", "Nonylphenol, 4-n-, Total", "Nonylphenol, p-, Dissolved", "Nonylphenol, p-, Particulate", "Nonylphenol, p-, Total", "Nonylphenol, tech-, Total", "Nonylphenol, Total", "Nonylphenol-13C6, 4-n-(Surrogate), Total", "Nonylphenolethoxylate, Total", "Norfloxacin, Total", "Norfluoxetine, Total", "Norfluoxetine-d5(Surrogate), Total", "Norflurazon, Dissolved", "Norflurazon, Not Recorded", "Norflurazon, Total", "Norgestimate, Total", "Norverapamil, Total", "Novaluron, Dissolved", "Novaluron, Particulate", "OCDD, 1,2,3,4,6,7,8,9- (TEQ ND=0), Total", "OCDD, 1,2,3,4,6,7,8,9- (TEQ ND=1/2 DL), Total", "OCDD, 1,2,3,4,6,7,8,9-(Surrogate), Total", "OCDD, 1,2,3,4,6,7,8,9-, Dissolved", "OCDD, 1,2,3,4,6,7,8,9-, Particulate", "OCDD, 1,2,3,4,6,7,8,9-, Total", "OCDD-13C, 1,2,3,4,6,7,8,9-(Surrogate), Dissolved", "OCDD-13C, 1,2,3,4,6,7,8,9-(Surrogate), Particulate", "OCDD-13C, 1,2,3,4,6,7,8,9-(Surrogate), Total", "OCDF, 1,2,3,4,6,7,8,9- (TEQ ND=0), Total", "OCDF, 1,2,3,4,6,7,8,9- (TEQ ND=1/2 DL), Total", "OCDF, 1,2,3,4,6,7,8,9-(Surrogate), Total", "OCDF, 1,2,3,4,6,7,8,9-, Dissolved", "OCDF, 1,2,3,4,6,7,8,9-, Particulate", "OCDF, 1,2,3,4,6,7,8,9-, Total", "OCDF-13C, 1,2,3,4,6,7,8,9-(Surrogate), Total", "Octachlorostyrene, Total", "Octachlorostyrene-13C8(Surrogate), Total", "Octacosane, n-(Surrogate), Total", "Octacosane, n-, Total", "Octadecane, n-, Total", "Octylphenol, Total", "Ofloxacin, Total", "OilandGrease, HEM, Total", "OilandGrease, SGT-HEM, Dissolved", "OilandGrease, SGT-HEM, Total", "Open Shell Volume, Total", "Ormetoprim, Total", "Oryzalin, Dissolved", "Oryzalin, Not Recorded", "Oryzalin, Total", "o-Terphenyl(Surrogate), Total", "Oxacillin, Total", "Oxadiazon, Dissolved", "Oxadiazon, Particulate", "Oxadiazon, Total", "Oxamyl, Dissolved", "Oxamyl, Not Recorded", "Oxamyl, Total", "Oxolinic Acid, Total", "Oxychlordane(Surrogate), Dissolved", "Oxychlordane(Surrogate), Particulate", "Oxychlordane(Surrogate), Total", "Oxychlordane, Dissolved", "Oxychlordane, Particulate", "Oxychlordane, Total", "Oxychlordane-13C10(Surrogate), Total", "Oxycodone, Total", "Oxycodone-d6(Surrogate), Total", "Oxyfluorfen, Dissolved", "Oxyfluorfen, Not Recorded", "Oxyfluorfen, Particulate", "Oxyfluorfen, Total", "Oxytetracycline, Total", "Paclobutrazol, Dissolved", "Paclobutrazol, Particulate", "Paraoxon, Not Recorded", "Paraoxon, Total", "Paraquat, Total", "Parathion, Ethyl, Not Recorded", "Parathion, Ethyl, Total", "Parathion, Methyl, Dissolved", "Parathion, Methyl, Not Recorded", "Parathion, Methyl, Particulate", "Parathion, Methyl, Total", "Paroxetine, Total", "Paroxetine-d6(Surrogate), Total", "PBB 001, Total", "PBB 002, Total", "PBB 003, Total", "PBB 004, Total", "PBB 007, Total", "PBB 009, Total", "PBB 010, Total", "PBB 015, Total", "PBB 018, Total", "PBB 026, Total", "PBB 030, Total", "PBB 031, Total", "PBB 049, Total", "PBB 052, Total", "PBB 053, Total", "PBB 077, Total", "PBB 080, Total", "PBB 103, Total", "PBB 155, Total", "PBDE 001(Surrogate), Total", "PBDE 001, Dissolved", "PBDE 001, Particulate", "PBDE 001, Total", "PBDE 002, Dissolved", "PBDE 002, Particulate", "PBDE 002, Total", "PBDE 003(Surrogate), Total", "PBDE 003, Dissolved", "PBDE 003, Particulate", "PBDE 003, Total", "PBDE 004(Surrogate), Total", "PBDE 007, Dissolved", "PBDE 007, Particulate", "PBDE 007, Total", "PBDE 008, Dissolved", "PBDE 008, Particulate", "PBDE 008, Total", "PBDE 008/11, Total", "PBDE 010, Dissolved", "PBDE 010, Particulate", "PBDE 010, Total", "PBDE 011, Dissolved", "PBDE 011, Particulate", "PBDE 011, Total", "PBDE 012, Dissolved", "PBDE 012, Particulate", "PBDE 012, Total", "PBDE 012/13, Total", "PBDE 013, Dissolved", "PBDE 013, Particulate", "PBDE 013, Total", "PBDE 015(Surrogate), Dissolved", "PBDE 015(Surrogate), Particulate", "PBDE 015(Surrogate), Total", "PBDE 015, Dissolved", "PBDE 015, Particulate", "PBDE 015, Total", "PBDE 017, Dissolved", "PBDE 017, Particulate", "PBDE 017, Total", "PBDE 017/25, Total", "PBDE 019(Surrogate), Total", "PBDE 025, Dissolved", "PBDE 025, Particulate", "PBDE 025, Total", "PBDE 028(Surrogate), Dissolved", "PBDE 028(Surrogate), Particulate", "PBDE 028(Surrogate), Total", "PBDE 028, Dissolved", "PBDE 028, Particulate", "PBDE 028, Total", "PBDE 028/33, Total", "PBDE 030, Dissolved", "PBDE 030, Particulate", "PBDE 030, Total", "PBDE 032, Dissolved", "PBDE 032, Particulate", "PBDE 032, Total", "PBDE 033, Dissolved", "PBDE 033, Particulate", "PBDE 033, Total", "PBDE 035, Dissolved", "PBDE 035, Particulate", "PBDE 035, Total", "PBDE 037(Surrogate), Total", "PBDE 037, Dissolved", "PBDE 037, Particulate", "PBDE 037, Total", "PBDE 047(Surrogate), Dissolved", "PBDE 047(Surrogate), Particulate", "PBDE 047(Surrogate), Total", "PBDE 047, Dissolved", "PBDE 047, Particulate", "PBDE 047, Total", "PBDE 049, Dissolved", "PBDE 049, Particulate", "PBDE 049, Total", "PBDE 049/71, Total", "PBDE 051, Dissolved", "PBDE 051, Particulate", "PBDE 051, Total", "PBDE 052(Surrogate), Total", "PBDE 054(Surrogate), Total", "PBDE 066, Dissolved", "PBDE 066, Particulate", "PBDE 066, Total", "PBDE 071, Dissolved", "PBDE 071, Particulate", "PBDE 071, Total", "PBDE 075, Dissolved", "PBDE 075, Particulate", "PBDE 075, Total", "PBDE 077(Surrogate), Dissolved", "PBDE 077(Surrogate), Particulate", "PBDE 077(Surrogate), Total", "PBDE 077, Dissolved", "PBDE 077, Particulate", "PBDE 077, Total", "PBDE 079, Dissolved", "PBDE 079, Particulate", "PBDE 079, Total", "PBDE 081(Surrogate), Total", "PBDE 085, Dissolved", "PBDE 085, Particulate", "PBDE 085, Total", "PBDE 099(Surrogate), Dissolved", "PBDE 099(Surrogate), Particulate", "PBDE 099(Surrogate), Total", "PBDE 099, Dissolved", "PBDE 099, Particulate", "PBDE 099, Total", "PBDE 100(Surrogate), Dissolved", "PBDE 100(Surrogate), Particulate", "PBDE 100(Surrogate), Total", "PBDE 100, Dissolved", "PBDE 100, Particulate", "PBDE 100, Total", "PBDE 100-L(Surrogate), Total", "PBDE 104(Surrogate), Total", "PBDE 105(Surrogate), Total", "PBDE 105, Dissolved", "PBDE 105, Particulate", "PBDE 105, Total", "PBDE 111(Surrogate), Total", "PBDE 114(Surrogate), Total", "PBDE 116, Dissolved", "PBDE 116, Particulate", "PBDE 116, Total", "PBDE 118(Surrogate), Total", "PBDE 118, Total", "PBDE 119, Dissolved", "PBDE 119, Particulate", "PBDE 119, Total", "PBDE 119/120, Total", "PBDE 120, Dissolved", "PBDE 120, Particulate", "PBDE 120, Total", "PBDE 123(Surrogate), Total", "PBDE 126(Surrogate), Dissolved", "PBDE 126(Surrogate), Particulate", "PBDE 126(Surrogate), Total", "PBDE 126, Dissolved", "PBDE 126, Particulate", "PBDE 126, Total", "PBDE 128, Dissolved", "PBDE 128, Particulate", "PBDE 128, Total", "PBDE 138(Surrogate), Dissolved", "PBDE 138(Surrogate), Total", "PBDE 138, Dissolved", "PBDE 138, Particulate", "PBDE 138, Total", "PBDE 138/166, Total", "PBDE 139(Surrogate), Dissolved", "PBDE 139(Surrogate), Particulate", "PBDE 139(Surrogate), Total", "PBDE 139, Total", "PBDE 140(Surrogate), Dissolved", "PBDE 140(Surrogate), Particulate", "PBDE 140(Surrogate), Total", "PBDE 140, Dissolved", "PBDE 140, Particulate", "PBDE 140, Total", "PBDE 153(Surrogate), Dissolved", "PBDE 153(Surrogate), Particulate", "PBDE 153(Surrogate), Total", "PBDE 153, Dissolved", "PBDE 153, Particulate", "PBDE 153, Total", "PBDE 154(Surrogate), Dissolved", "PBDE 154(Surrogate), Particulate", "PBDE 154(Surrogate), Total", "PBDE 154, Dissolved", "PBDE 154, Particulate", "PBDE 154, Total", "PBDE 155(Surrogate), Total", "PBDE 155, Dissolved", "PBDE 155, Particulate", "PBDE 155, Total", "PBDE 156(Surrogate), Total", "PBDE 160, Total", "PBDE 166, Dissolved", "PBDE 166, Particulate", "PBDE 166, Total", "PBDE 167(Surrogate), Total", "PBDE 169(Surrogate), Total", "PBDE 170(Surrogate), Total", "PBDE 178(Surrogate), Total", "PBDE 179, Total", "PBDE 180(Surrogate), Total", "PBDE 181, Dissolved", "PBDE 181, Particulate", "PBDE 181, Total", "PBDE 183(Surrogate), Dissolved", "PBDE 183(Surrogate), Particulate", "PBDE 183(Surrogate), Total", "PBDE 183, Dissolved", "PBDE 183, Particulate", "PBDE 183, Total", "PBDE 184, Total", "PBDE 188(Surrogate), Total", "PBDE 188, Total", "PBDE 189(Surrogate), Total", "PBDE 190, Dissolved", "PBDE 190, Particulate", "PBDE 190, Total", "PBDE 194, Total", "PBDE 195, Total", "PBDE 196, Total", "PBDE 197(Surrogate), Dissolved", "PBDE 197(Surrogate), Particulate", "PBDE 197(Surrogate), Total", "PBDE 197, Dissolved", "PBDE 197, Particulate", "PBDE 197, Total", "PBDE 198, Total", "PBDE 200, Total", "PBDE 200/203, Total", "PBDE 201, Total", "PBDE 202(Surrogate), Total", "PBDE 202, Total", "PBDE 203, Dissolved", "PBDE 203, Particulate", "PBDE 203, Total", "PBDE 204, Total", "PBDE 205(Surrogate), Total", "PBDE 205, Dissolved", "PBDE 205, Particulate", "PBDE 205, Total", "PBDE 206(Surrogate), Total", "PBDE 206, Dissolved", "PBDE 206, Particulate", "PBDE 206, Total", "PBDE 207(Surrogate), Total", "PBDE 207, Dissolved", "PBDE 207, Particulate", "PBDE 207, Total", "PBDE 208(Surrogate), Total", "PBDE 208, Dissolved", "PBDE 208, Particulate", "PBDE 208, Total", "PBDE 209(Surrogate), Dissolved", "PBDE 209(Surrogate), Particulate", "PBDE 209(Surrogate), Total", "PBDE 209, Dissolved", "PBDE 209, Particulate", "PBDE 209, Total", "PCB 001(Surrogate), Dissolved", "PCB 001(Surrogate), Particulate", "PCB 001(Surrogate), Total", "PCB 001, Dissolved", "PCB 001, Particulate", "PCB 001, Total", "PCB 002, Dissolved", "PCB 002, Particulate", "PCB 002, Total", "PCB 003(Surrogate), Dissolved", "PCB 003(Surrogate), Particulate", "PCB 003(Surrogate), Total", "PCB 003, Dissolved", "PCB 003, Particulate", "PCB 003, Total", "PCB 004(Surrogate), Dissolved", "PCB 004(Surrogate), Particulate", "PCB 004(Surrogate), Total", "PCB 004, Dissolved", "PCB 004, Particulate", "PCB 004, Total", "PCB 004/10, Total", "PCB 005, Dissolved", "PCB 005, Particulate", "PCB 005, Total", "PCB 005/8, Total", "PCB 006, Dissolved", "PCB 006, Particulate", "PCB 006, Total", "PCB 007, Dissolved", "PCB 007, Particulate", "PCB 007, Total", "PCB 007/9, Total", "PCB 008(Surrogate), Total", "PCB 008, Dissolved", "PCB 008, Particulate", "PCB 008, Total", "PCB 009(Surrogate), Total", "PCB 009, Dissolved", "PCB 009, Particulate", "PCB 009, Total", "PCB 009-13C(Surrogate), Total", "PCB 010, Dissolved", "PCB 010, Particulate", "PCB 010, Total", "PCB 011, Dissolved", "PCB 011, Particulate", "PCB 011, Total", "PCB 011-13C(Surrogate), Total", "PCB 012, Dissolved", "PCB 012, Particulate", "PCB 012, Total", "PCB 012/13, Total", "PCB 013, Dissolved", "PCB 013, Particulate", "PCB 013, Total", "PCB 014, Dissolved", "PCB 014, Particulate", "PCB 014, Total", "PCB 015(Surrogate), Dissolved", "PCB 015(Surrogate), Particulate", "PCB 015(Surrogate), Total", "PCB 015, Dissolved", "PCB 015, Particulate", "PCB 015, Total", "PCB 016, Dissolved", "PCB 016, Particulate", "PCB 016, Total", "PCB 016/32, Total", "PCB 017, Dissolved", "PCB 017, Particulate", "PCB 017, Total", "PCB 017/18, Total", "PCB 018, Dissolved", "PCB 018, Particulate", "PCB 018, Total", "PCB 018/30, Total", "PCB 019(Surrogate), Dissolved", "PCB 019(Surrogate), Particulate", "PCB 019(Surrogate), Total", "PCB 019, Dissolved", "PCB 019, Particulate", "PCB 019, Total", "PCB 020, Dissolved", "PCB 020, Particulate", "PCB 020, Total", "PCB 020/21/33, Total", "PCB 020/28, Total", "PCB 021, Dissolved", "PCB 021, Particulate", "PCB 021, Total", "PCB 021/33, Total", "PCB 022, Dissolved", "PCB 022, Particulate", "PCB 022, Total", "PCB 023, Dissolved", "PCB 023, Particulate", "PCB 023, Total", "PCB 024, Dissolved", "PCB 024, Particulate", "PCB 024, Total", "PCB 024/27, Total", "PCB 025, Dissolved", "PCB 025, Particulate", "PCB 025, Total", "PCB 026, Dissolved", "PCB 026, Particulate", "PCB 026, Total", "PCB 026/29, Total", "PCB 027, Dissolved", "PCB 027, Particulate", "PCB 027, Total", "PCB 028(Surrogate), Dissolved", "PCB 028(Surrogate), Particulate", "PCB 028(Surrogate), Total", "PCB 028, Dissolved", "PCB 028, Particulate", "PCB 028, Total", "PCB 028/31, Total", "PCB 028-13C(Surrogate), Total", "PCB 029, Dissolved", "PCB 029, Particulate", "PCB 029, Total", "PCB 030(Surrogate), Total", "PCB 030, Dissolved", "PCB 030, Particulate", "PCB 030, Total", "PCB 031(Surrogate), Dissolved", "PCB 031(Surrogate), Total", "PCB 031, Dissolved", "PCB 031, Particulate", "PCB 031, Total", "PCB 032, Dissolved", "PCB 032, Particulate", "PCB 032, Total", "PCB 032-13C(Surrogate), Total", "PCB 033, Dissolved", "PCB 033, Particulate", "PCB 033, Total", "PCB 034, Dissolved", "PCB 034, Particulate", "PCB 034, Total", "PCB 035, Dissolved", "PCB 035, Particulate", "PCB 035, Total", "PCB 036, Dissolved", "PCB 036, Particulate", "PCB 036, Total", "PCB 037(Surrogate), Dissolved", "PCB 037(Surrogate), Particulate", "PCB 037(Surrogate), Total", "PCB 037, Dissolved", "PCB 037, Particulate", "PCB 037, Total", "PCB 038, Dissolved", "PCB 038, Particulate", "PCB 038, Total", "PCB 039, Dissolved", "PCB 039, Particulate", "PCB 039, Total", "PCB 040, Dissolved", "PCB 040, Particulate", "PCB 040, Total", "PCB 040/41, Total", "PCB 040/41/71, Total", "PCB 040/71, Total", "PCB 041, Dissolved", "PCB 041, Particulate", "PCB 041, Total", "PCB 041/64/71/72, Total", "PCB 042, Dissolved", "PCB 042, Particulate", "PCB 042, Total", "PCB 042/59, Total", "PCB 043, Dissolved", "PCB 043, Particulate", "PCB 043, Total", "PCB 043/49, Total", "PCB 044, Dissolved", "PCB 044, Particulate", "PCB 044, Total", "PCB 044/47, Total", "PCB 044/47/65, Total", "PCB 044/65, Total", "PCB 045, Dissolved", "PCB 045, Particulate", "PCB 045, Total", "PCB 045/51, Total", "PCB 046, Dissolved", "PCB 046, Particulate", "PCB 046, Total", "PCB 047, Dissolved", "PCB 047, Particulate", "PCB 047, Total", "PCB 047-13C(Surrogate), Total", "PCB 048, Dissolved", "PCB 048, Particulate", "PCB 048, Total", "PCB 048/75, Total", "PCB 049, Dissolved", "PCB 049, Particulate", "PCB 049, Total", "PCB 049/69, Total", "PCB 050, Dissolved", "PCB 050, Particulate", "PCB 050, Total", "PCB 050/53, Total", "PCB 051, Dissolved", "PCB 051, Particulate", "PCB 051, Total", "PCB 052(Surrogate), Total", "PCB 052, Dissolved", "PCB 052, Particulate", "PCB 052, Total", "PCB 052/69, Total", "PCB 052-13C(Surrogate), Total", "PCB 053, Dissolved", "PCB 053, Particulate", "PCB 053, Total", "PCB 054(Surrogate), Dissolved", "PCB 054(Surrogate), Particulate", "PCB 054(Surrogate), Total", "PCB 054, Dissolved", "PCB 054, Particulate", "PCB 054, Total", "PCB 055, Dissolved", "PCB 055, Particulate", "PCB 055, Total", "PCB 056, Dissolved", "PCB 056, Particulate", "PCB 056, Total", "PCB 056/60, Total", "PCB 057, Dissolved", "PCB 057, Particulate", "PCB 057, Total", "PCB 058, Dissolved", "PCB 058, Particulate", "PCB 058, Total", "PCB 059, Dissolved", "PCB 059, Particulate", "PCB 059, Total", "PCB 059/62, Total", "PCB 059/62/75, Total", "PCB 059/75, Total", "PCB 060, Dissolved", "PCB 060, Particulate", "PCB 060, Total", "PCB 061, Dissolved", "PCB 061, Particulate", "PCB 061, Total", "PCB 061/70, Total", "PCB 061/70/74/76, Total", "PCB 061/74, Total", "PCB 061/76, Total", "PCB 062, Dissolved", "PCB 062, Particulate", "PCB 062, Total", "PCB 063, Dissolved", "PCB 063, Particulate", "PCB 063, Total", "PCB 064, Dissolved", "PCB 064, Particulate", "PCB 064, Total", "PCB 065(Surrogate), Total", "PCB 065, Dissolved", "PCB 065, Particulate", "PCB 065, Total", "PCB 066, Dissolved", "PCB 066, Particulate", "PCB 066, Total", "PCB 066/76, Total", "PCB 067, Dissolved", "PCB 067, Particulate", "PCB 067, Total", "PCB 068, Dissolved", "PCB 068, Particulate", "PCB 068, Total", "PCB 069, Dissolved", "PCB 069, Particulate", "PCB 069, Total", "PCB 070, Dissolved", "PCB 070, Particulate", "PCB 070, Total", "PCB 070/74, Total", "PCB 070/76, Total", "PCB 070-13C(Surrogate), Total", "PCB 071, Dissolved", "PCB 071, Particulate", "PCB 071, Total", "PCB 072, Dissolved", "PCB 072, Particulate", "PCB 072, Total", "PCB 073, Dissolved", "PCB 073, Particulate", "PCB 073, Total", "PCB 074, Dissolved", "PCB 074, Particulate", "PCB 074, Total", "PCB 075, Dissolved", "PCB 075, Particulate", "PCB 075, Total", "PCB 076, Dissolved", "PCB 076, Particulate", "PCB 076, Total", "PCB 076/66, Total", "PCB 077 (TEQ ND=0), Dissolved", "PCB 077 (TEQ ND=0), Particulate", "PCB 077 (TEQ ND=0), Total", "PCB 077 (TEQ ND=1/2 DL), Dissolved", "PCB 077 (TEQ ND=1/2 DL), Particulate", "PCB 077 (TEQ ND=1/2 DL), Total", "PCB 077 (TEQ ND=DL), Dissolved", "PCB 077 (TEQ ND=DL), Particulate", "PCB 077 (TEQ ND=DL), Total", "PCB 077(Surrogate), Dissolved", "PCB 077(Surrogate), Particulate", "PCB 077(Surrogate), Total", "PCB 077, Dissolved", "PCB 077, Particulate", "PCB 077, Total", "PCB 077/110, Total", "PCB 077-13C(Surrogate), Total", "PCB 078, Dissolved", "PCB 078, Particulate", "PCB 078, Total", "PCB 079, Dissolved", "PCB 079, Particulate", "PCB 079, Total", "PCB 079-13C(Surrogate), Total", "PCB 080, Dissolved", "PCB 080, Particulate", "PCB 080, Total", "PCB 080-13C(Surrogate), Total", "PCB 081 (TEQ ND=0), Dissolved", "PCB 081 (TEQ ND=0), Particulate", "PCB 081 (TEQ ND=0), Total", "PCB 081 (TEQ ND=1/2 DL), Dissolved", "PCB 081 (TEQ ND=1/2 DL), Particulate", "PCB 081 (TEQ ND=1/2 DL), Total", "PCB 081 (TEQ ND=DL), Dissolved", "PCB 081 (TEQ ND=DL), Particulate", "PCB 081 (TEQ ND=DL), Total", "PCB 081(Surrogate), Dissolved", "PCB 081(Surrogate), Particulate", "PCB 081(Surrogate), Total", "PCB 081, Dissolved", "PCB 081, Particulate", "PCB 081, Total", "PCB 082, Dissolved", "PCB 082, Particulate", "PCB 082, Total", "PCB 083, Dissolved", "PCB 083, Particulate", "PCB 083, Total", "PCB 083/99, Total", "PCB 084, Dissolved", "PCB 084, Particulate", "PCB 084, Total", "PCB 084/92, Total", "PCB 085, Dissolved", "PCB 085, Particulate", "PCB 085, Total", "PCB 085/116, Total", "PCB 085/116/117, Total", "PCB 085/117, Total", "PCB 086, Dissolved", "PCB 086, Particulate", "PCB 086, Total", "PCB 086/108, Total", "PCB 086/119, Total", "PCB 086/125, Total", "PCB 086/87, Total", "PCB 086/87/97/108/119/125, Total", "PCB 086/97, Total", "PCB 087, Dissolved", "PCB 087, Particulate", "PCB 087, Total", "PCB 087/108, Total", "PCB 087/115, Total", "PCB 087/117/125, Total", "PCB 087/119, Total", "PCB 087/125, Total", "PCB 087/97, Total", "PCB 088, Dissolved", "PCB 088, Particulate", "PCB 088, Total", "PCB 088/91, Total", "PCB 089, Dissolved", "PCB 089, Particulate", "PCB 089, Total", "PCB 090, Dissolved", "PCB 090, Particulate", "PCB 090, Total", "PCB 090/101, Total", "PCB 090/101/113, Total", "PCB 090/113, Total", "PCB 091, Dissolved", "PCB 091, Particulate", "PCB 091, Total", "PCB 092, Dissolved", "PCB 092, Particulate", "PCB 092, Total", "PCB 093, Dissolved", "PCB 093, Particulate", "PCB 093, Total", "PCB 093/100, Total", "PCB 093/102, Total", "PCB 093/95, Total", "PCB 093/95/98/100/102, Total", "PCB 093/98, Total", "PCB 094, Dissolved", "PCB 094, Particulate", "PCB 094, Total", "PCB 095(Surrogate), Dissolved", "PCB 095(Surrogate), Total", "PCB 095, Dissolved", "PCB 095, Particulate", "PCB 095, Total", "PCB 095/100, Total", "PCB 095/102, Total", "PCB 095/98, Total", "PCB 095/98/102, Total", "PCB 095-13C(Surrogate), Total", "PCB 096, Dissolved", "PCB 096, Particulate", "PCB 096, Total", "PCB 097, Dissolved", "PCB 097, Particulate", "PCB 097, Total", "PCB 097-13C(Surrogate), Total", "PCB 098, Dissolved", "PCB 098, Particulate", "PCB 098, Total", "PCB 099, Dissolved", "PCB 099, Particulate", "PCB 099, Total", "PCB 100, Dissolved", "PCB 100, Particulate", "PCB 100, Total", "PCB 101(Surrogate), Total", "PCB 101, Dissolved", "PCB 101, Particulate", "PCB 101, Total", "PCB 101/113, Total", "PCB 101-13C(Surrogate), Total", "PCB 102, Dissolved", "PCB 102, Particulate", "PCB 102, Total", "PCB 103(Surrogate), Total", "PCB 103, Dissolved", "PCB 103, Particulate", "PCB 103, Total", "PCB 104(Surrogate), Dissolved", "PCB 104(Surrogate), Particulate", "PCB 104(Surrogate), Total", "PCB 104, Dissolved", "PCB 104, Particulate", "PCB 104, Total", "PCB 105 (TEQ ND=0), Dissolved", "PCB 105 (TEQ ND=0), Particulate", "PCB 105 (TEQ ND=0), Total", "PCB 105 (TEQ ND=1/2 DL), Dissolved", "PCB 105 (TEQ ND=1/2 DL), Particulate", "PCB 105 (TEQ ND=1/2 DL), Total", "PCB 105 (TEQ ND=DL), Dissolved", "PCB 105 (TEQ ND=DL), Particulate", "PCB 105 (TEQ ND=DL), Total", "PCB 105(Surrogate), Dissolved", "PCB 105(Surrogate), Particulate", "PCB 105(Surrogate), Total", "PCB 105, Dissolved", "PCB 105, Particulate", "PCB 105, Total", "PCB 105-13C(Surrogate), Total", "PCB 106, Dissolved", "PCB 106, Particulate", "PCB 106, Total", "PCB 106/118, Total", "PCB 107, Dissolved", "PCB 107, Particulate", "PCB 107, Total", "PCB 107/109, Total", "PCB 107/124, Total", "PCB 108, Dissolved", "PCB 108, Particulate", "PCB 108, Total", "PCB 108/112, Total", "PCB 109, Dissolved", "PCB 109, Particulate", "PCB 109, Total", "PCB 110, Dissolved", "PCB 110, Particulate", "PCB 110, Total", "PCB 110/115, Total", "PCB 110/151, Total", "PCB 111(Surrogate), Dissolved", "PCB 111(Surrogate), Particulate", "PCB 111(Surrogate), Total", "PCB 111, Dissolved", "PCB 111, Particulate", "PCB 111, Total", "PCB 111/115, Total", "PCB 112(Surrogate), Total", "PCB 112, Dissolved", "PCB 112, Particulate", "PCB 112, Total", "PCB 113, Dissolved", "PCB 113, Particulate", "PCB 113, Total", "PCB 114 (TEQ ND=0), Dissolved", "PCB 114 (TEQ ND=0), Particulate", "PCB 114 (TEQ ND=0), Total", "PCB 114 (TEQ ND=1/2 DL), Dissolved", "PCB 114 (TEQ ND=1/2 DL), Particulate", "PCB 114 (TEQ ND=1/2 DL), Total", "PCB 114 (TEQ ND=DL), Dissolved", "PCB 114 (TEQ ND=DL), Particulate", "PCB 114 (TEQ ND=DL), Total", "PCB 114(Surrogate), Dissolved", "PCB 114(Surrogate), Particulate", "PCB 114(Surrogate), Total", "PCB 114, Dissolved", "PCB 114, Particulate", "PCB 114, Total", "PCB 114/153, Total", "PCB 115, Dissolved", "PCB 115, Particulate", "PCB 115, Total", "PCB 116, Dissolved", "PCB 116, Particulate", "PCB 116, Total", "PCB 117, Dissolved", "PCB 117, Particulate", "PCB 117, Total", "PCB 118 (TEQ ND=0), Dissolved", "PCB 118 (TEQ ND=0), Particulate", "PCB 118 (TEQ ND=0), Total", "PCB 118 (TEQ ND=1/2 DL), Dissolved", "PCB 118 (TEQ ND=1/2 DL), Particulate", "PCB 118 (TEQ ND=1/2 DL), Total", "PCB 118 (TEQ ND=DL), Dissolved", "PCB 118 (TEQ ND=DL), Particulate", "PCB 118 (TEQ ND=DL), Total", "PCB 118(Surrogate), Dissolved", "PCB 118(Surrogate), Particulate", "PCB 118(Surrogate), Total", "PCB 118, Dissolved", "PCB 118, Particulate", "PCB 118, Total", "PCB 118-13C(Surrogate), Total", "PCB 119, Dissolved", "PCB 119, Particulate", "PCB 119, Total", "PCB 120, Dissolved", "PCB 120, Particulate", "PCB 120, Total", "PCB 121, Dissolved", "PCB 121, Particulate", "PCB 121, Total", "PCB 122, Dissolved", "PCB 122, Particulate", "PCB 122, Total", "PCB 123 (TEQ ND=0), Dissolved", "PCB 123 (TEQ ND=0), Particulate", "PCB 123 (TEQ ND=0), Total", "PCB 123 (TEQ ND=1/2 DL), Dissolved", "PCB 123 (TEQ ND=1/2 DL), Particulate", "PCB 123 (TEQ ND=1/2 DL), Total", "PCB 123 (TEQ ND=DL), Dissolved", "PCB 123 (TEQ ND=DL), Particulate", "PCB 123 (TEQ ND=DL), Total", "PCB 123(Surrogate), Dissolved", "PCB 123(Surrogate), Particulate", "PCB 123(Surrogate), Total", "PCB 123, Dissolved", "PCB 123, Particulate", "PCB 123, Total", "PCB 123/149, Total", "PCB 123-13C(Surrogate), Total", "PCB 124, Dissolved", "PCB 124, Particulate", "PCB 124, Total", "PCB 125, Dissolved", "PCB 125, Particulate", "PCB 125, Total", "PCB 126 (TEQ ND=0), Dissolved", "PCB 126 (TEQ ND=0), Particulate", "PCB 126 (TEQ ND=0), Total", "PCB 126 (TEQ ND=1/2 DL), Dissolved", "PCB 126 (TEQ ND=1/2 DL), Particulate", "PCB 126 (TEQ ND=1/2 DL), Total", "PCB 126 (TEQ ND=DL), Dissolved", "PCB 126 (TEQ ND=DL), Particulate", "PCB 126 (TEQ ND=DL), Total", "PCB 126(Surrogate), Dissolved", "PCB 126(Surrogate), Particulate", "PCB 126(Surrogate), Total", "PCB 126, Dissolved", "PCB 126, Particulate", "PCB 126, Total", "PCB 126-13C(Surrogate), Total", "PCB 127, Dissolved", "PCB 127, Particulate", "PCB 127, Total", "PCB 127-13C(Surrogate), Total", "PCB 128, Dissolved", "PCB 128, Particulate", "PCB 128, Total", "PCB 128/162, Total", "PCB 128/166, Total", "PCB 128/167, Total", "PCB 129, Dissolved", "PCB 129, Particulate", "PCB 129, Total", "PCB 129/138, Total", "PCB 129/138/160/163, Total", "PCB 129/160, Total", "PCB 129/163, Total", "PCB 129/166, Total", "PCB 130, Dissolved", "PCB 130, Particulate", "PCB 130, Total", "PCB 131, Dissolved", "PCB 131, Particulate", "PCB 131, Total", "PCB 132, Dissolved", "PCB 132, Particulate", "PCB 132, Total", "PCB 132/153, Total", "PCB 132/153/168, Total", "PCB 132/161, Total", "PCB 132/168, Total", "PCB 133, Dissolved", "PCB 133, Particulate", "PCB 133, Total", "PCB 133/142, Total", "PCB 134, Dissolved", "PCB 134, Particulate", "PCB 134, Total", "PCB 134/143, Total", "PCB 135, Dissolved", "PCB 135, Particulate", "PCB 135, Total", "PCB 135/151, Total", "PCB 135/151/154, Total", "PCB 135/154, Total", "PCB 136, Dissolved", "PCB 136, Particulate", "PCB 136, Total", "PCB 137, Dissolved", "PCB 137, Particulate", "PCB 137, Total", "PCB 138(Surrogate), Total", "PCB 138, Dissolved", "PCB 138, Particulate", "PCB 138, Total", "PCB 138/158, Total", "PCB 138/160, Total", "PCB 138/163, Total", "PCB 138/163/164, Total", "PCB 138-13C(Surrogate), Total", "PCB 139, Dissolved", "PCB 139, Particulate", "PCB 139, Total", "PCB 139/140, Total", "PCB 139/149, Total", "PCB 140, Dissolved", "PCB 140, Particulate", "PCB 140, Total", "PCB 141, Dissolved", "PCB 141, Particulate", "PCB 141, Total", "PCB 141-13C(Surrogate), Total", "PCB 142, Dissolved", "PCB 142, Particulate", "PCB 142, Total", "PCB 143, Dissolved", "PCB 143, Particulate", "PCB 143, Total", "PCB 144, Dissolved", "PCB 144, Particulate", "PCB 144, Total", "PCB 145, Dissolved", "PCB 145, Particulate", "PCB 145, Total", "PCB 146, Dissolved", "PCB 146, Particulate", "PCB 146, Total", "PCB 146/165, Total", "PCB 147, Dissolved", "PCB 147, Particulate", "PCB 147, Total", "PCB 147/149, Total", "PCB 148, Dissolved", "PCB 148, Particulate", "PCB 148, Total", "PCB 149, Dissolved", "PCB 149, Particulate", "PCB 149, Total", "PCB 150, Dissolved", "PCB 150, Particulate", "PCB 150, Total", "PCB 151, Dissolved", "PCB 151, Particulate", "PCB 151, Total", "PCB 151/154, Total", "PCB 152, Dissolved", "PCB 152, Particulate", "PCB 152, Total", "PCB 153(Surrogate), Dissolved", "PCB 153(Surrogate), Total", "PCB 153, Dissolved", "PCB 153, Particulate", "PCB 153, Total", "PCB 153/168, Total", "PCB 153-13C(Surrogate), Total", "PCB 154, Dissolved", "PCB 154, Particulate", "PCB 154, Total", "PCB 155(Surrogate), Dissolved", "PCB 155(Surrogate), Particulate", "PCB 155(Surrogate), Total", "PCB 155, Dissolved", "PCB 155, Particulate", "PCB 155, Total", "PCB 155-13C(Surrogate), Total", "PCB 156 (TEQ ND=0), Dissolved", "PCB 156 (TEQ ND=0), Particulate", "PCB 156 (TEQ ND=0), Total", "PCB 156 (TEQ ND=1/2 DL), Dissolved", "PCB 156 (TEQ ND=1/2 DL), Particulate", "PCB 156 (TEQ ND=1/2 DL), Total", "PCB 156 (TEQ ND=DL), Dissolved", "PCB 156 (TEQ ND=DL), Particulate", "PCB 156 (TEQ ND=DL), Total", "PCB 156(Surrogate), Dissolved", "PCB 156(Surrogate), Particulate", "PCB 156(Surrogate), Total", "PCB 156, Dissolved", "PCB 156, Particulate", "PCB 156, Total", "PCB 156/157 (TEQ ND=0), Dissolved", "PCB 156/157 (TEQ ND=0), Particulate", "PCB 156/157 (TEQ ND=0), Total", "PCB 156/157 (TEQ ND=1/2 DL), Dissolved", "PCB 156/157 (TEQ ND=1/2 DL), Particulate", "PCB 156/157 (TEQ ND=1/2 DL), Total", "PCB 156/157 (TEQ ND=DL), Dissolved", "PCB 156/157 (TEQ ND=DL), Particulate", "PCB 156/157 (TEQ ND=DL), Total", "PCB 156/157(Surrogate), Total", "PCB 156/157, Total", "PCB 156/171/202, Total", "PCB 156-13C(Surrogate), Total", "PCB 157 (TEQ ND=0), Total", "PCB 157 (TEQ ND=1/2 DL), Total", "PCB 157 (TEQ ND=DL), Total", "PCB 157(Surrogate), Dissolved", "PCB 157(Surrogate), Particulate", "PCB 157(Surrogate), Total", "PCB 157, Dissolved", "PCB 157, Particulate", "PCB 157, Total", "PCB 157/173/201, Total", "PCB 157/180, Total", "PCB 158, Dissolved", "PCB 158, Particulate", "PCB 158, Total", "PCB 158/160, Total", "PCB 159(Surrogate), Dissolved", "PCB 159(Surrogate), Particulate", "PCB 159(Surrogate), Total", "PCB 159, Dissolved", "PCB 159, Particulate", "PCB 159, Total", "PCB 159-13C(Surrogate), Total", "PCB 160, Dissolved", "PCB 160, Particulate", "PCB 160, Total", "PCB 161, Dissolved", "PCB 161, Particulate", "PCB 161, Total", "PCB 162, Dissolved", "PCB 162, Particulate", "PCB 162, Total", "PCB 163, Dissolved", "PCB 163, Particulate", "PCB 163, Total", "PCB 164, Dissolved", "PCB 164, Particulate", "PCB 164, Total", "PCB 165, Dissolved", "PCB 165, Particulate", "PCB 165, Total", "PCB 166, Dissolved", "PCB 166, Particulate", "PCB 166, Total", "PCB 167 (TEQ ND=0), Dissolved", "PCB 167 (TEQ ND=0), Particulate", "PCB 167 (TEQ ND=0), Total", "PCB 167 (TEQ ND=1/2 DL), Dissolved", "PCB 167 (TEQ ND=1/2 DL), Particulate", "PCB 167 (TEQ ND=1/2 DL), Total", "PCB 167 (TEQ ND=DL), Dissolved", "PCB 167 (TEQ ND=DL), Particulate", "PCB 167 (TEQ ND=DL), Total", "PCB 167(Surrogate), Dissolved", "PCB 167(Surrogate), Particulate", "PCB 167(Surrogate), Total", "PCB 167, Dissolved", "PCB 167, Particulate", "PCB 167, Total", "PCB 168, Dissolved", "PCB 168, Particulate", "PCB 168, Total", "PCB 168/132, Total", "PCB 169 (TEQ ND=0), Dissolved", "PCB 169 (TEQ ND=0), Particulate", "PCB 169 (TEQ ND=0), Total", "PCB 169 (TEQ ND=1/2 DL), Dissolved", "PCB 169 (TEQ ND=1/2 DL), Particulate", "PCB 169 (TEQ ND=1/2 DL), Total", "PCB 169 (TEQ ND=DL), Dissolved", "PCB 169 (TEQ ND=DL), Particulate", "PCB 169 (TEQ ND=DL), Total", "PCB 169(Surrogate), Dissolved", "PCB 169(Surrogate), Particulate", "PCB 169(Surrogate), Total", "PCB 169, Dissolved", "PCB 169, Particulate", "PCB 169, Total", "PCB 169-13C(Surrogate), Total", "PCB 170(Surrogate), Dissolved", "PCB 170(Surrogate), Particulate", "PCB 170(Surrogate), Total", "PCB 170, Dissolved", "PCB 170, Particulate", "PCB 170, Total", "PCB 170/190, Total", "PCB 170-13C(Surrogate), Total", "PCB 171, Dissolved", "PCB 171, Particulate", "PCB 171, Total", "PCB 171/173, Total", "PCB 172, Dissolved", "PCB 172, Particulate", "PCB 172, Total", "PCB 173, Dissolved", "PCB 173, Particulate", "PCB 173, Total", "PCB 174, Dissolved", "PCB 174, Particulate", "PCB 174, Total", "PCB 175, Dissolved", "PCB 175, Particulate", "PCB 175, Total", "PCB 176, Dissolved", "PCB 176, Particulate", "PCB 176, Total", "PCB 177, Dissolved", "PCB 177, Particulate", "PCB 177, Total", "PCB 178(Surrogate), Dissolved", "PCB 178(Surrogate), Particulate", "PCB 178(Surrogate), Total", "PCB 178, Dissolved", "PCB 178, Particulate", "PCB 178, Total", "PCB 178-13C(Surrogate), Total", "PCB 179, Dissolved", "PCB 179, Particulate", "PCB 179, Total", "PCB 180(Surrogate), Dissolved", "PCB 180(Surrogate), Particulate", "PCB 180(Surrogate), Total", "PCB 180, Dissolved", "PCB 180, Particulate", "PCB 180, Total", "PCB 180/193, Total", "PCB 180-13C(Surrogate), Total", "PCB 181, Dissolved", "PCB 181, Particulate", "PCB 181, Total", "PCB 182, Dissolved", "PCB 182, Particulate", "PCB 182, Total", "PCB 182/187, Total", "PCB 183, Dissolved", "PCB 183, Particulate", "PCB 183, Total", "PCB 183/185, Total", "PCB 184, Dissolved", "PCB 184, Particulate", "PCB 184, Total", "PCB 185, Dissolved", "PCB 185, Particulate", "PCB 185, Total", "PCB 186, Dissolved", "PCB 186, Particulate", "PCB 186, Total", "PCB 187, Dissolved", "PCB 187, Particulate", "PCB 187, Total", "PCB 188(Surrogate), Dissolved", "PCB 188(Surrogate), Particulate", "PCB 188(Surrogate), Total", "PCB 188, Dissolved", "PCB 188, Particulate", "PCB 188, Total", "PCB 188-13C(Surrogate), Total", "PCB 189 (TEQ ND=0), Dissolved", "PCB 189 (TEQ ND=0), Particulate", "PCB 189 (TEQ ND=0), Total", "PCB 189 (TEQ ND=1/2 DL), Dissolved", "PCB 189 (TEQ ND=1/2 DL), Particulate", "PCB 189 (TEQ ND=1/2 DL), Total", "PCB 189 (TEQ ND=DL), Dissolved", "PCB 189 (TEQ ND=DL), Particulate", "PCB 189 (TEQ ND=DL), Total", "PCB 189(Surrogate), Dissolved", "PCB 189(Surrogate), Particulate", "PCB 189(Surrogate), Total", "PCB 189, Dissolved", "PCB 189, Particulate", "PCB 189, Total", "PCB 190, Dissolved", "PCB 190, Particulate", "PCB 190, Total", "PCB 191, Dissolved", "PCB 191, Particulate", "PCB 191, Total", "PCB 192, Dissolved", "PCB 192, Particulate", "PCB 192, Total", "PCB 193, Dissolved", "PCB 193, Particulate", "PCB 193, Total", "PCB 194(Surrogate), Total", "PCB 194, Dissolved", "PCB 194, Particulate", "PCB 194, Total", "PCB 194-13C(Surrogate), Total", "PCB 195, Dissolved", "PCB 195, Particulate", "PCB 195, Total", "PCB 195/208, Total", "PCB 196, Dissolved", "PCB 196, Particulate", "PCB 196, Total", "PCB 196/203, Total", "PCB 197, Dissolved", "PCB 197, Particulate", "PCB 197, Total", "PCB 197/200, Total", "PCB 198(Surrogate), Total", "PCB 198, Dissolved", "PCB 198, Particulate", "PCB 198, Total", "PCB 198/199, Total", "PCB 199, Dissolved", "PCB 199, Particulate", "PCB 199, Total", "PCB 200, Dissolved", "PCB 200, Particulate", "PCB 200, Total", "PCB 201, Dissolved", "PCB 201, Particulate", "PCB 201, Total", "PCB 202(Surrogate), Dissolved", "PCB 202(Surrogate), Particulate", "PCB 202(Surrogate), Total", "PCB 202, Dissolved", "PCB 202, Particulate", "PCB 202, Total", "PCB 202-13C(Surrogate), Total", "PCB 203, Dissolved", "PCB 203, Particulate", "PCB 203, Total", "PCB 204, Dissolved", "PCB 204, Particulate", "PCB 204, Total", "PCB 205(Surrogate), Dissolved", "PCB 205(Surrogate), Particulate", "PCB 205(Surrogate), Total", "PCB 205, Dissolved", "PCB 205, Particulate", "PCB 205, Total", "PCB 206(Surrogate), Dissolved", "PCB 206(Surrogate), Particulate", "PCB 206(Surrogate), Total", "PCB 206, Dissolved", "PCB 206, Particulate", "PCB 206, Total", "PCB 207(Surrogate), Total", "PCB 207, Dissolved", "PCB 207, Particulate", "PCB 207, Total", "PCB 208(Surrogate), Dissolved", "PCB 208(Surrogate), Particulate", "PCB 208(Surrogate), Total", "PCB 208, Dissolved", "PCB 208, Particulate", "PCB 208, Total", "PCB 209(Surrogate), Dissolved", "PCB 209(Surrogate), Particulate", "PCB 209(Surrogate), Total", "PCB 209(Surrogate)DB-608, Total", "PCB 209(Surrogate)HP-5, Total", "PCB 209, Dissolved", "PCB 209, Particulate", "PCB 209, Total", "PCB AROCLOR 1016, Total", "PCB AROCLOR 1221, Total", "PCB AROCLOR 1232, Total", "PCB AROCLOR 1242, Total", "PCB AROCLOR 1248, Total", "PCB AROCLOR 1254, Total", "PCB AROCLOR 1260, Total", "PCB TOTAL (TEQ ND=0), Dissolved", "PCB TOTAL (TEQ ND=0), Particulate", "PCB TOTAL (TEQ ND=0), Total", "PCB TOTAL (TEQ ND=1/2 DL), Dissolved", "PCB TOTAL (TEQ ND=1/2 DL), Particulate", "PCB TOTAL (TEQ ND=1/2 DL), Total", "PCB TOTAL (TEQ ND=DL), Dissolved", "PCB TOTAL (TEQ ND=DL), Particulate", "PCB TOTAL (TEQ ND=DL), Total", "PCNB, Dissolved", "PCNB, Particulate", "PCNB, Total", "PCT AROCLOR 5460, Total", "Pebulate, Dissolved", "Pebulate, Particulate", "Pebulate, Total", "PECDD, 1,2,3,7,8- (TEQ ND=0), Total", "PECDD, 1,2,3,7,8- (TEQ ND=1/2 DL), Total", "PeCDD, 1,2,3,7,8-(Surrogate), Total", "PeCDD, 1,2,3,7,8-, Dissolved", "PeCDD, 1,2,3,7,8-, Particulate", "PeCDD, 1,2,3,7,8-, Total", "PeCDD-13C, 1,2,3,7,8-(Surrogate), Dissolved", "PeCDD-13C, 1,2,3,7,8-(Surrogate), Particulate", "PeCDD-13C, 1,2,3,7,8-(Surrogate), Total", "PECDF, 1,2,3,7,8- (TEQ ND=0), Total", "PECDF, 1,2,3,7,8- (TEQ ND=1/2 DL), Total", "PeCDF, 1,2,3,7,8-(Surrogate), Total", "PeCDF, 1,2,3,7,8-, Dissolved", "PeCDF, 1,2,3,7,8-, Particulate", "PeCDF, 1,2,3,7,8-, Total", "PECDF, 2,3,4,7,8- (TEQ ND=0), Total", "PECDF, 2,3,4,7,8- (TEQ ND=1/2 DL), Total", "PeCDF, 2,3,4,7,8-(Surrogate), Total", "PeCDF, 2,3,4,7,8-, Dissolved", "PeCDF, 2,3,4,7,8-, Particulate", "PeCDF, 2,3,4,7,8-, Total", "PeCDF-13C, 1,2,3,7,8-(Surrogate), Dissolved", "PeCDF-13C, 1,2,3,7,8-(Surrogate), Particulate", "PeCDF-13C, 1,2,3,7,8-(Surrogate), Total", "PeCDF-13C, 2,3,4,7,8-(Surrogate), Dissolved", "PeCDF-13C, 2,3,4,7,8-(Surrogate), Particulate", "PeCDF-13C, 2,3,4,7,8-(Surrogate), Total", "Pendimethalin, Dissolved", "Pendimethalin, Not Recorded", "Pendimethalin, Particulate", "Pendimethalin, Total", "Penicillin G, Total", "Penicillin V, Total", "Penoxsulam, Dissolved", "Penoxsulam, Total", "Pentachloroanisole, Dissolved", "Pentachloroanisole, Particulate", "Pentachloroanisole, Total", "Pentachlorobenzene(Surrogate), Total", "Pentachlorobenzene, Total", "Pentachloroethane, Total", "Pentachloronitrobenzene, Dissolved", "Pentachloronitrobenzene, Particulate", "Pentachloronitrobenzene, Total", "Pentachlorophenol, Total", "Perfluorobutanesulfonate, Total", "Perfluorobutanoate(Surrogate), Total", "Perfluorobutanoate, Total", "Perfluorobutanoate-13C4(Surrogate), Total", "Perfluorodecanoate(Surrogate), Total", "Perfluorodecanoate, Total", "Perfluorodecanoate-13C2(Surrogate), Total", "Perfluorododecanoate(Surrogate), Total", "Perfluorododecanoate, Total", "Perfluorododecanoate-13C2(Surrogate), Total", "Perfluoroheptanoate, Total", "Perfluorohexanesulfonate, Total", "Perfluorohexanesulfonate-18O2(Surrogate), Total", "Perfluorohexanoate(Surrogate), Total", "Perfluorohexanoate, Total", "Perfluorohexanoate-13C2(Surrogate), Total", "Perfluorononanoate(Surrogate), Total", "Perfluorononanoate, Total", "Perfluorononanoate-13C5(Surrogate), Total", "Perfluorooctanesulfonamide, Total", "Perfluorooctanesulfonamide-13C8(Surrogate), Total", "Perfluorooctanesulfonate 080(Surrogate), Total", "Perfluorooctanesulfonate, Total", "Perfluorooctanesulfonate-13C4(Surrogate), Total", "Perfluorooctanoate(Surrogate), Total", "Perfluorooctanoate, Total", "Perfluorooctanoate-13C2(Surrogate), Total", "Perfluorooctanoate-13C8(Surrogate), Total", "Perfluoropentanoate, Total", "Perfluoroundecanoate, Total", "Permethrin, cis-(Surrogate), Particulate", "Permethrin, cis-, Total", "Permethrin, Total, Dissolved", "Permethrin, Total, Particulate", "Permethrin, Total, Total", "Permethrin, trans-, Total", "Permethrin-13C6, cis-(Surrogate), Total", "Perthane, Total", "Perylene, Dissolved", "Perylene, Particulate", "Perylene, Total", "Perylene-d12(Surrogate), Dissolved", "Perylene-d12(Surrogate), Particulate", "Perylene-d12(Surrogate), Total", "Phenanthrene, Dissolved", "Phenanthrene, Particulate", "Phenanthrene, Total", "Phenanthrene/Anthracene, C1-, Dissolved", "Phenanthrene/Anthracene, C1-, Particulate", "Phenanthrene/Anthracene, C1-, Total", "Phenanthrene/Anthracene, C2-, Dissolved", "Phenanthrene/Anthracene, C2-, Particulate", "Phenanthrene/Anthracene, C2-, Total", "Phenanthrene/Anthracene, C3-, Dissolved", "Phenanthrene/Anthracene, C3-, Particulate", "Phenanthrene/Anthracene, C3-, Total", "Phenanthrene/Anthracene, C4-, Dissolved", "Phenanthrene/Anthracene, C4-, Particulate", "Phenanthrene/Anthracene, C4-, Total", "Phenanthrene-d10(Surrogate), Dissolved", "Phenanthrene-d10(Surrogate), Particulate", "Phenanthrene-d10(Surrogate), Total", "Phenol, Total", "Phenol-d5(Surrogate), Total", "Phenol-d6(Surrogate), Total", "Phenolics, Total, Total", "Phenothrin, Dissolved", "Phenothrin, Particulate", "Phenothrin, Total", "Phorate, Not Recorded", "Phorate, Total", "Phosalone Oxon, Not Recorded", "Phosalone, Not Recorded", "Phosalone, Total", "Phosmet, Dissolved", "Phosmet, Not Recorded", "Phosmet, Particulate", "Phosmet, Total", "Phosmet-Oxon, Not Recorded", "Phosphamidon, Total", "Phytane, Dissolved", "Phytane, Particulate", "Phytane, Total", "Picloram, Dissolved", "Picloram, Total", "Picoxystrobin, Dissolved", "Picoxystrobin, Particulate", "Piperonyl Butoxide, Dissolved", "Piperonyl Butoxide, Particulate", "Piperonyl Butoxide, Total", "Pirimiphos Methyl, Total", "Prallethrin, Total", "Prednisolone, Total", "Prednisone, Total", "Pristane, Dissolved", "Pristane, Particulate", "Pristane, Total", "Procymidone, Total", "Prodiamine, Dissolved", "Prodiamine, Not Recorded", "Prodiamine, Particulate", "Prodiamine, Total", "Profenofos, Not Recorded", "Profenofos, Total", "Profluralin, Total", "Promethazine, Total", "Promethazine-d4(Surrogate), Total", "Prometon, Dissolved", "Prometon, Not Recorded", "Prometon, Particulate", "Prometon, Total", "Prometryn, Dissolved", "Prometryn, Not Recorded", "Prometryn, Particulate", "Prometryn, Total", "Pronamide, Total", "Propachlor, Total", "Propanil, Dissolved", "Propanil, Not Recorded", "Propanil, Particulate", "Propanil, Total", "Propargite, Dissolved", "Propargite, Particulate", "Propargite, Total", "Propazine, Dissolved", "Propazine, Total", "Propham, Dissolved", "Propham, Total", "Propiconazole, Dissolved", "Propiconazole, Particulate", "Propiconazole, Total", "Propoxur, Dissolved", "Propoxur, Total", "Propoxyphene, Total", "Propoxyphene-d5(Surrogate), Total", "Propranolol, Total", "Propranolol-d7(Surrogate), Total", "Propylbenzene, n-, Total", "Propyzamide, Dissolved", "Propyzamide, Particulate", "p-Terphenyl-d14(Surrogate), Total", "Pymetrozin, Total", "Pyraclostrobin, Dissolved", "Pyraclostrobin, Not Recorded", "Pyraclostrobin, Particulate", "Pyraclostrobin, Total", "Pyrene, Dissolved", "Pyrene, Particulate", "Pyrene, Total", "Pyrene-d10(Surrogate), Total", "Pyrethrin-1, Dissolved", "Pyrethrin-1, Total", "Pyrethrin-2, Dissolved", "Pyrethrin-2, Total", "Pyridaben, Dissolved", "Pyridaben, Particulate", "Pyridine, Total", "Pyrimethanil, Dissolved", "Pyrimethanil, Particulate", "Pyriproxyfen, Not Recorded", "Quinoxyfen, Dissolved", "Quinoxyfen, Particulate", "Ranitidine, Total", "Resmethrin, Dissolved", "Resmethrin, Not Recorded", "Resmethrin, Particulate", "Resmethrin, Total", "Retene, Dissolved", "Retene, Particulate", "Retene, Total", "Roxithromycin, Total", "Safrotin, Total", "Sarafloxacin, Total", "Sealed Shell Volume, Total", "Secbumeton, Dissolved", "Secbumeton, Total", "Sedaxane, Dissolved", "Sedaxane, Particulate", "Selenomethionine, Dissolved", "Sertraline, Total", "Siduron, Dissolved", "Siduron, Total", "Simazine(Surrogate), Dissolved", "Simazine(Surrogate), Total", "Simazine, Dissolved", "Simazine, Not Recorded", "Simazine, Particulate", "Simazine, Total", "Simetryn, Dissolved", "Simetryn, Total", "Simvastatin, Total", "Styrene, Total", "Sulfachloropyridazine, Total", "Sulfadiazine, Total", "Sulfadimethoxine, Total", "Sulfallate, Total", "Sulfamerazine, Total", "Sulfamethazine, Total", "Sulfamethazine-13C6(Surrogate), Total", "Sulfamethizole, Total", "Sulfamethoxazole, Total", "Sulfamethoxazole-13C6(Surrogate), Total", "Sulfanilamide, Total", "Sulfathiazole, Total", "Sulfometuron Methyl, Dissolved", "Sulfotep, Total", "Sum of DDTs (RWQCB3), Total", "TCDD, 2,3,7,8- (TEQ ND=0), Total", "TCDD, 2,3,7,8- (TEQ ND=1/2 DL), Total", "TCDD, 2,3,7,8-(Surrogate), Total", "TCDD, 2,3,7,8-, Dissolved", "TCDD, 2,3,7,8-, Particulate", "TCDD, 2,3,7,8-, Total", "TCDD-13C, 2,3,7,8-(Surrogate), Dissolved", "TCDD-13C, 2,3,7,8-(Surrogate), Particulate", "TCDD-13C, 2,3,7,8-(Surrogate), Total", "TCDD-13C6, 1,2,3,4-(Surrogate), Dissolved", "TCDD-13C6, 1,2,3,4-(Surrogate), Total", "TCDD-37Cl, 2,3,7,8-(Surrogate), Dissolved", "TCDD-37Cl, 2,3,7,8-(Surrogate), Particulate", "TCDD-37Cl, 2,3,7,8-(Surrogate), Total", "TCDF, 2,3,7,8- (TEQ ND=0), Total", "TCDF, 2,3,7,8- (TEQ ND=1/2 DL), Total", "TCDF, 2,3,7,8-(Surrogate), Total", "TCDF, 2,3,7,8-, Dissolved", "TCDF, 2,3,7,8-, Particulate", "TCDF, 2,3,7,8-, Total", "TCDF-13C, 2,3,7,8-(Surrogate), Dissolved", "TCDF-13C, 2,3,7,8-(Surrogate), Particulate", "TCDF-13C, 2,3,7,8-(Surrogate), Total", "TCDF-2C, 2,3,7,8-, Total", "Tebuconazole, Dissolved", "Tebuconazole, Particulate", "Tebuconazole, Total", "Tebufenozide, Not Recorded", "Tebupirimfos oxon, Dissolved", "Tebupirimfos oxon, Particulate", "Tebupirimfos, Dissolved", "Tebupirimfos, Particulate", "Tebuthiuron(Surrogate), Total", "Tebuthiuron, Dissolved", "Tebuthiuron, Not Recorded", "Tebuthiuron, Total", "Tedion, Total", "Temephos, Total", "Terbacil, Dissolved", "Terbacil, Total", "Terbufos Sulfone, Total", "Terbufos, Total", "Terbuthylazine, Dissolved", "Terbuthylazine, Total", "Terbutryn, Dissolved", "Terbutryn, Total", "Terphenyl-d14(Surrogate), Total", "Terpineol, alpha-, Total", "Tert-amyl Methyl Ether, Total", "Tert-butyl Alcohol, Total", "Tetrabromobisphenyl A, Total", "Tetrabutyltin as Sn, Total", "Tetrachlorobenzene, 1,2,3,4-(Surrogate), Dissolved", "Tetrachlorobenzene, 1,2,3,4-(Surrogate), Particulate", "Tetrachlorobenzene, 1,2,3,4-(Surrogate), Total", "Tetrachlorobenzene, 1,2,3,4-, Total", "Tetrachlorobenzene, 1,2,4,5-, Total", "Tetrachloroethane, 1,1,1,2-, Total", "Tetrachloroethane, 1,1,2,2-, Total", "Tetrachloroethylene, Total", "Tetrachloro-m-xylene(Surrogate), Dissolved", "Tetrachloro-m-xylene(Surrogate), Particulate", "Tetrachloro-m-xylene(Surrogate), Total", "Tetrachloro-m-xylene, Dissolved", "Tetrachloro-m-xylene, Particulate", "Tetrachloro-m-xylene, Total", "Tetrachlorophenol, 2,3,4,5-, Total", "Tetrachlorophenol, 2,3,4,6-, Total", "Tetrachlorophenol, 2,3,5,6-, Total", "Tetrachlorophenol, Total", "Tetrachlorvinphos, Total", "Tetraconazole, Dissolved", "Tetraconazole, Particulate", "Tetraconazole, Total", "Tetracosane, n-(Surrogate), Total", "Tetracosane, n-, Total", "Tetracycline, Total", "Tetradecane, 2-phenyl-, Total", "Tetradecane, 3-phenyl-, Total", "Tetradecane, 4-phenyl-, Total", "Tetradecane, 5-phenyl-, Total", "Tetradecane, 6-phenyl-, Total", "Tetradecane, 7-phenyl-, Total", "Tetradecane, n-, Total", "Tetradifon, Dissolved", "Tetradifon, Particulate", "Tetradifon, Total", "Tetraethyl Pyrophosphate, Total", "Tetramethrin, Dissolved", "Tetramethrin, Particulate", "Tetramethrin, Total", "Tetramethylnaphthalene, 1,4,6,7-, Dissolved", "Tetramethylnaphthalene, 1,4,6,7-, Particulate", "Tetramethylnaphthalene, 1,4,6,7-, Total", "T-Fluvalinate, Dissolved", "T-Fluvalinate, Particulate", "T-Fluvalinate, Total", "Theophylline, Total", "Theophylline-13C1-15N2(Surrogate), Total", "Thiabendazole, Dissolved", "Thiabendazole, Total", "Thiabendazole-d6(Surrogate), Total", "Thiacloprid, Dissolved", "Thiazopyr, Dissolved", "Thiazopyr, Particulate", "Thiobencarb(Surrogate), Total", "Thiobencarb, Dissolved", "Thiobencarb, Not Recorded", "Thiobencarb, Particulate", "Thiobencarb, Total", "Thionazin, Total", "Thiram, Not Recorded", "Tokuthion, Total", "Tolfenpyrad, Dissolved", "Toluene, Total", "Toluene-d8(Surrogate), Total", "Tonalide, Total", "Total Chlordanes, Total", "Total DDDs, Total", "Total DDEs, Total", "Total DDTs, Total", "Total Dichlorobiphenyls, Dissolved", "Total Dichlorobiphenyls, Particulate", "Total Dichlorobiphenyls, Total", "Total Dioxins-Furans (TEQ ND=0), Total", "Total Dioxins-Furans (TEQ ND=1/2 DL), Total", "Total HCHs, Total", "Total Heptachlorobiphenyls, Dissolved", "Total Heptachlorobiphenyls, Particulate", "Total Heptachlorobiphenyls, Total", "Total Hepta-Dioxins, Total", "Total Hepta-Furans, Total", "Total Hexachlorobiphenyls, Dissolved", "Total Hexachlorobiphenyls, Particulate", "Total Hexachlorobiphenyls, Total", "Total Hexa-Dioxins, Total", "Total Hexa-Furans, Total", "Total Monochlorobiphenyls, Dissolved", "Total Monochlorobiphenyls, Particulate", "Total Monochlorobiphenyls, Total", "Total Nonachlorobiphenyls, Dissolved", "Total Nonachlorobiphenyls, Particulate", "Total Nonachlorobiphenyls, Total", "Total Octachlorobiphenyls, Dissolved", "Total Octachlorobiphenyls, Particulate", "Total Octachlorobiphenyls, Total", "Total PAHs, Total", "Total PCBs, Dissolved", "Total PCBs, Particulate", "Total PCBs, Total", "Total Pentachlorobiphenyls, Dissolved", "Total Pentachlorobiphenyls, Particulate", "Total Pentachlorobiphenyls, Total", "Total Penta-Dioxins, Total", "Total Penta-Furans, Total", "Total Pyrethrins, Total", "Total Tetrachlorobiphenyls, Dissolved", "Total Tetrachlorobiphenyls, Particulate", "Total Tetrachlorobiphenyls, Total", "Total Tetra-Dioxins, Total", "Total Tetra-Furans, Total", "Total Tetra-PCB, Total", "Total Trichlorobiphenyls, Dissolved", "Total Trichlorobiphenyls, Particulate", "Total Trichlorobiphenyls, Total", "Toxaphene, Dissolved", "Toxaphene, Particulate", "Toxaphene, Total", "TPH as Diesel C10-C22, Total", "TPH as Diesel C10-C24, Total", "TPH as Diesel C10-C25, Total", "TPH as Diesel C10-C28, Total", "TPH as Diesel C11-C12, Total", "TPH as Diesel C12-C24, Total", "TPH as Diesel C12-C25, Total", "TPH as Diesel C13-C14, Total", "TPH as Diesel C13-C22, Total", "TPH as Diesel C15-C16, Total", "TPH as Diesel C17-C18, Total", "TPH as Diesel C19-C20, Total", "TPH as Diesel C21-C22, Total", "TPH as Diesel C23-C24, Total", "TPH as Diesel C25-C28, Total", "TPH as Diesel C8-C21, Total", "TPH as Gasoline C4-C12, Total", "TPH as Gasoline C6, Total", "TPH as Gasoline C6-C10, Total", "TPH as Gasoline C6-C12, Total", "TPH as Gasoline C7, Total", "TPH as Gasoline C8, Total", "TPH as Gasoline C9-C10, Total", "TPH as Heavy Fuel Oils C22-C36, Total", "TPH as JP8 C7-C18, Total", "TPH as Motor Oil C18-C36, Total", "TPH as Motor Oil C21-C32, Total", "TPH as Motor Oil C23-C40, Total", "TPH as Motor Oil C24-C36, Total", "TPH as Motor Oil C25-C36, Total", "TPH as Residual C29-C32, Total", "TPH as Residual C33-C36, Total", "TPH as Residual C37-C40, Total", "TPH as Residual C41-C44, Total", "Tralomethrin, Total", "Trenbolone Acetate, Total", "Trenbolone, Total", "Triacontane, n-, Total", "Triadimefon, Dissolved", "Triadimefon, Particulate", "Triadimenol, Dissolved", "Triadimenol, Particulate", "Triallate , Dissolved", "Triallate , Particulate", "Triamterene, Total", "Tribromophenol, 2,4,6-(Surrogate), Total", "Tribromophenol, 2,4,6-, Total", "Tributyl Phosphorotrithioate, S,S,S-, Dissolved", "Tributyl Phosphorotrithioate, S,S,S-, Not Recorded", "Tributyl Phosphorotrithioate, S,S,S-, Particulate", "Tributyl Phosphorotrithioate, S,S,S-, Total", "Tributylphosphate(Surrogate), Total", "Tributylphosphate, Total", "Tributyltin as Sn, Total", "Tributyltin as Sn-d27(Surrogate), Total", "Trichlorfon, Total", "Trichloro-1,2,2-trifluoroethane, 1,1,2-, Total", "Trichloro-2-pyridinyl)oxy)acetic Acid, ((3,5,6-, Dissolved", "Trichloro-2-pyridinyl)oxy)acetic Acid, ((3,5,6-, Total", "Trichlorobenzene, 1,2,3-(Surrogate), Total", "Trichlorobenzene, 1,2,3-, Total", "Trichlorobenzene, 1,2,4-, Total", "Trichloroethane, 1,1,1-, Total", "Trichloroethane, 1,1,2-, Total", "Trichloroethylene, Total", "Trichlorofluoromethane, Total", "Trichloronate, Total", "Trichlorophenol, 2,3,6-, Total", "Trichlorophenol, 2,4,5-, Total", "Trichlorophenol, 2,4,6-, Total", "Trichlorophenoxy)propionic Acid, 2-(2,4,5-, Total", "Trichlorophenoxyacetic Acid, 2,4,5-(Surrogate), Dissolved", "Trichlorophenoxyacetic Acid, 2,4,5-(Surrogate), Total", "Trichlorophenoxyacetic Acid, 2,4,5-, Total", "Trichloropropane, 1,2,3-, Total", "Triclocarban, Total", "Triclocarban-13C6(Surrogate), Total", "Triclopyr, Not Recorded", "Triclopyr, Total", "Triclosan, Total", "Triclosan-13C12(Surrogate), Total", "Triclosan-13C6(Surrogate), Total", "Tridecane, 2-phenyl-, Total", "Tridecane, 3-phenyl-, Total", "Tridecane, 4-phenyl-, Total", "Tridecane, 5-phenyl-, Total", "Tridecane, 6/7-phenyl-, Total", "Tridimephon, Total", "Trifloxystrobin, Dissolved", "Trifloxystrobin, Not Recorded", "Trifloxystrobin, Particulate", "Trifloxystrobin, Total", "Triflumizole, Dissolved", "Triflumizole, Particulate", "Triflumizole, Total", "Trifluorotolunene, a,a,a-(Surrogate), Total", "Trifluralin, Dissolved", "Trifluralin, Not Recorded", "Trifluralin, Particulate", "Trifluralin, Total", "Trifluralin-d14(Surrogate), Dissolved", "Trifluralin-d14(Surrogate), Particulate", "Trihalomethanes, Total, Total", "Trimethoprim, Total", "Trimethoprim-13C3(Surrogate), Total", "Trimethylbenzene, 1,2,4-, Total", "Trimethylbenzene, 1,3,5-, Total", "Trimethylnaphthalene, 1,6,7-, Total", "Trimethylnaphthalene, 2,3,5-, Dissolved", "Trimethylnaphthalene, 2,3,5-, Particulate", "Trimethylnaphthalene, 2,3,5-, Total", "Trimethylnaphthalene, 2,3,6-, Dissolved", "Trimethylnaphthalene, 2,3,6-, Particulate", "Trimethylnaphthalene, 2,3,6-, Total", "Trimethylphenanthrene, 1,2,6-, Dissolved", "Trimethylphenanthrene, 1,2,6-, Particulate", "Trimethylphenanthrene, 1,2,6-, Total", "Trimethylphenol, 2,4,6-(Surrogate), Total", "Triphenyl Phosphate(Surrogate), Dissolved", "Triphenyl Phosphate(Surrogate), Particulate", "Triphenyl Phosphate(Surrogate), Total", "Triphenyl Phosphate, Dissolved", "Triphenyl Phosphate, Particulate", "Triphenyl Phosphate, Total", "Tripropyltin(Surrogate), Total", "Tris(1,1-dimethylethyl)phenol, 2,4,6-, Total", "Tris-Methane, Dissolved", "Tris-Methane, Particulate", "Tris-Methane, Total", "Tris-Methanol, Dissolved", "Tris-Methanol, Particulate", "Tris-Methanol, Total", "Trithion, Methyl, Total", "Triticonazole, Dissolved", "Triticonazole, Particulate", "TRPH, Total", "Tylosin, Total", "Undecane, 2-phenyl-, Total", "Undecane, 3-phenyl-, Total", "Undecane, 4-phenyl-, Total", "Undecane, 5-phenyl-, Total", "Undecane, 6-phenyl-, Total", "Urea, Dissolved", "Urea, Total", "Valsartan, Total", "Verapamil, Total", "Versalide, Total", "Vinclozolin, Total", "Vinyl Chloride, Total", "Virginiamycin, Total", "Warfarin, Total", "Warfarin-d5(Surrogate), Total", "Xylene, m/p-, Total", "Xylene, o-, Total", "Xylenes, Total, Total", "Zoxamide, Dissolved", "Zoxamide, Particulate", ]
WaterChem = FILES["WaterChemistryData"]
path, fileName = os.path.split(WaterChem)
newFileName = 'Organics_DataMartList' + extension
column_filter = 'Analyte'
name, location, sitesname, siteslocation = selectByAnalyte(path=path, fileName=fileName, newFileName=newFileName, analytes=analytes,
		                field_filter=column_filter, sep=sep)
FILES[name] = location
FILES[sitesname] = siteslocation
print("\t\tFinished writing data subset for Organics\n\n")
############################## ^^^^^^^^^^^^^^^^^^^^^^^^^^  Subsets of datasets for Organics ^^^^^^^^^^^^^^^^^^^^^^^^^^ ##########################################







######################################################### Pesticides_v2 (Below) ############################################################################################################
import pyodbc
import os
import csv
import re
from datetime import datetime
import string
import getpass
from dkan.client import DatasetAPI
    
print("\nStarting data subset for Pesticides_v2....")
        # NEW
FILES = {'Pesticides_v2.csv': 'C:\\Users\\daltare\\Documents\\CEDEN_Datasets\\Pesticides_v2.csv', 'WaterChemistryData': 'C:\\Users\\daltare\\Documents\\CEDEN_Datasets\\WaterChemistryData.csv',}
sep = ','
extension = '.csv'
# Get the 'selectByAnalyte' function
### The analytes below are derived from the dbo_Parameter_Groups table in the datamart, filtered for 'Pesticides', 'OrganochlorinePesticides', 'Pesticides/PCBs', and 'Pyrethroid Pesticides' 
analytes = ["Acetamiprid, Dissolved", "Acetamiprid, Total", "Acibenzolar-S-methyl, Dissolved", "Acibenzolar-S-methyl, Particulate", "Acrolein, Total", "Alachlor ethanesulfonic acid, Not Recorded", "Alachlor oxanilic acid, Not Recorded", "Aldicarb Sulfone, Dissolved", "Aldicarb Sulfone, Not Recorded", "Aldicarb Sulfone, Total", "Aldicarb Sulfoxide, Dissolved", "Aldicarb Sulfoxide, Not Recorded", "Aldicarb Sulfoxide, Total", "Aldicarb, Dissolved", "Aldicarb, Not Recorded", "Aldicarb, Total", "Aldrin(Surrogate), Dissolved", "Aldrin(Surrogate), Particulate", "Aldrin(Surrogate), Total", "Aldrin, Dissolved", "Aldrin, Particulate", "Aldrin, Total", "Aldrin-13C12(Surrogate), Total", "Allethrin, Dissolved", "Allethrin, Particulate", "Allethrin, Total", "Ametryn, Dissolved", "Ametryn, Total", "Aminocarb, Total", "AMPA(Surrogate), Total", "AMPA, Dissolved", "AMPA, Total", "Anilazine, Total", "Aspon, Total", "Atraton, Dissolved", "Atraton, Total", "Atrazine, Dissolved", "Atrazine, Not Recorded", "Atrazine, Particulate", "Atrazine, Total", "Atrazine-13C3(Surrogate), Dissolved", "Atrazine-13C3(Surrogate), Total", "Atrazine-d5(Surrogate), Total", "Azinphos Ethyl, Total", "Azinphos Methyl oxon, Dissolved", "Azinphos Methyl oxon, Particulate", "Azinphos Methyl, Dissolved", "Azinphos Methyl, Not Recorded", "Azinphos Methyl, Particulate", "Azinphos Methyl, Total", "Azinphos-methyl oxygen analog, Not Recorded", "Azoxystrobin, Dissolved", "Azoxystrobin, Not Recorded", "Azoxystrobin, Particulate", "Azoxystrobin, Total", "Barban(Surrogate), Dissolved", "Barban, Total", "Bendiocarb, Dissolved", "Benfluralin, Dissolved", "Benfluralin, Particulate", "Benfluralin, Total", "Benomyl, Dissolved", "Benomyl, Total", "Benomyl/Carbendazim, Total", "Bensulfuron Methyl, Dissolved", "Bensulfuron Methyl, Total", "Bentazon, Dissolved", "Bentazon, Total", "Bifenox, Total", "Bifenthrin, Dissolved", "Bifenthrin, Not Recorded", "Bifenthrin, Particulate", "Bifenthrin, Total", "Bispyribac Sodium, Total", "Bolstar, Total", "Bromacil, Dissolved", "Bromacil, Not Recorded", "Bromacil, Total", "Bromo-3,5-dimethylphenyl-N-methylcarbamate, 4-(Surrogate), Dissolved", "Bromo-3,5-dimethylphenyl-N-methylcarbamate, 4-(Surrogate), Total", "Bromuconazole, Dissolved", "Bromuconazole, Particulate", "Butralin, Dissolved", "Butralin, Particulate", "Butylate, Dissolved", "Butylate, Particulate", "Butylate, Total", "Butyl-N-ethyl-2,6-dinitro-4-(trifluoromethyl)aniline, N-, Not Recorded", "Captafol, Total", "Captan, Dissolved", "Captan, Particulate", "Captan, Total", "Carbaryl, Dissolved", "Carbaryl, Not Recorded", "Carbaryl, Particulate", "Carbaryl, Total", "Carbendazim, Dissolved", "Carbofuran, Dissolved", "Carbofuran, Not Recorded", "Carbofuran, Particulate", "Carbofuran, Total", "Carbophenothion, Total", "Carfentrazone Ethyl, Total", "Celestolide, Total", "Chemical Group A, Total", "Chlorantraniliprole, Dissolved", "Chlorbenside, Total", "Chlordane, cis-(Surrogate), Total", "Chlordane, cis-, Dissolved", "Chlordane, cis-, Particulate", "Chlordane, cis-, Total", "Chlordane, Technical, Total", "Chlordane, Total", "Chlordane, trans-(Surrogate), Dissolved", "Chlordane, trans-(Surrogate), Particulate", "Chlordane, trans-(Surrogate), Total", "Chlordane, trans-, Dissolved", "Chlordane, trans-, Particulate", "Chlordane, trans-, Total", "Chlordene, cis-, Total", "Chlordene, Total", "Chlordene, trans-, Total", "Chlorfenapyr, Not Recorded", "Chlorfenapyr, Total", "Chlorfenvinphos, Total", "Chlorobenzilate, Total", "Chloroneb(Surrogate), Total", "Chlorothalonil, Dissolved", "Chlorothalonil, Not Recorded", "Chlorothalonil, Particulate", "Chlorothalonil, Total", "Chloroxuron(Surrogate), Total", "Chlorpropham, Total", "Chlorpyrifos Methyl(Surrogate), Total", "Chlorpyrifos Methyl, Dissolved", "Chlorpyrifos Methyl, Particulate", "Chlorpyrifos Methyl, Total", "Chlorpyrifos Oxon, Dissolved", "Chlorpyrifos Oxon, Not Recorded", "Chlorpyrifos Oxon, Particulate", "Chlorpyrifos(Surrogate), Total", "Chlorpyrifos, Dissolved", "Chlorpyrifos, Not Recorded", "Chlorpyrifos, Particulate", "Chlorpyrifos, Total", "Cinerin-1, Dissolved", "Cinerin-1, Total", "Cinerin-2, Dissolved", "Cinerin-2, Total", "Ciodrin, Total", "Clomazone, Dissolved", "Clomazone, Particulate", "Clomazone, Total", "Clothianidin, Dissolved", "Clothianidin, Total", "Coumaphos, Dissolved", "Coumaphos, Particulate", "Coumaphos, Total", "Cyanazine, Dissolved", "Cyanazine, Not Recorded", "Cyanazine, Total", "Cyantraniliprole, Dissolved", "Cyazofamid, Dissolved", "Cycloate, Dissolved", "Cycloate, Particulate", "Cycloate, Total", "Cyfluthrin, beta-, Total", "Cyfluthrin, total, Dissolved", "Cyfluthrin, total, Particulate", "Cyfluthrin, total, Total", "Cyfluthrin-1, Total", "Cyfluthrin-2, Total", "Cyfluthrin-3, Total", "Cyfluthrin-4, Total", "Cyhalofop-butyl, Dissolved", "Cyhalofop-butyl, Particulate", "Cyhalofop-butyl, Total", "Cyhalothrin, Dissolved", "Cyhalothrin, gamma-, Total", "Cyhalothrin, lambda-1, Total", "Cyhalothrin, lambda-2, Total", "Cyhalothrin, Particulate", "Cyhalothrin, Total", "Cyhalothrin, Total lambda-, Total", "Cymoxanil, Dissolved", "Cypermethrin, Total, Dissolved", "Cypermethrin, Total, Particulate", "Cypermethrin, Total, Total", "Cypermethrin-1, Total", "Cypermethrin-13C6(Surrogate), Total", "Cypermethrin-2, Total", "Cypermethrin-3, Total", "Cypermethrin-4, Total", "Cyproconazole, Dissolved", "Cyproconazole, Particulate", "Cyprodinil, Dissolved", "Cyprodinil, Particulate", "Dacthal, Dissolved", "Dacthal, Particulate", "Dacthal, Total", "DBCE(Surrogate), Total", "DCBP(p,p'), Total", "DDD(o,p')(Surrogate), Total", "DDD(o,p'), Dissolved", "DDD(o,p'), Particulate", "DDD(o,p'), Total", "DDD(o,p')/PCB 118, Total", "DDD(p,p')(Surrogate), Dissolved", "DDD(p,p')(Surrogate), Particulate", "DDD(p,p')(Surrogate), Total", "DDD(p,p'), Dissolved", "DDD(p,p'), Particulate", "DDD(p,p'), Total", "DDD-13C(p,p')(Surrogate), Particulate", "DDE(o,p')(Surrogate), Dissolved", "DDE(o,p')(Surrogate), Particulate", "DDE(o,p')(Surrogate), Total", "DDE(o,p'), Dissolved", "DDE(o,p'), Particulate", "DDE(o,p'), Total", "DDE(p,p')(Surrogate), Dissolved", "DDE(p,p')(Surrogate), Particulate", "DDE(p,p')(Surrogate), Total", "DDE(p,p'), Dissolved", "DDE(p,p'), Particulate", "DDE(p,p'), Total", "DDE(p,p')/PCB 087, Total", "DDMS(p,p'), Total", "DDMU(p,p'), Dissolved", "DDMU(p,p'), Particulate", "DDMU(p,p'), Total", "DDT(o,p')(Surrogate), Dissolved", "DDT(o,p')(Surrogate), Particulate", "DDT(o,p')(Surrogate), Total", "DDT(o,p'), Dissolved", "DDT(o,p'), Particulate", "DDT(o,p'), Total", "DDT(p,p')(Surrogate), Dissolved", "DDT(p,p')(Surrogate), Particulate", "DDT(p,p')(Surrogate), Total", "DDT(p,p'), Dissolved", "DDT(p,p'), Particulate", "DDT(p,p'), Total", "DDT(p,p')/PCB 187, Total", "Deltamethrin, Dissolved", "Deltamethrin, Not Recorded", "Deltamethrin, Particulate", "Deltamethrin, Total", "Deltamethrin/Tralomethrin, Total", "Demeton, Total, Total", "Demeton-O, Total", "Demeton-s, Total", "Desethyl-Atrazine, Dissolved", "Desethyl-Atrazine, Not Recorded", "Desethyl-Atrazine, Total", "Desethyl-desisopropyl-atrazine, Dissolved", "Desethyl-desisopropyl-atrazine, Total", "Desisopropyl-Atrazine, Dissolved", "Desisopropyl-Atrazine, Not Recorded", "Desisopropyl-Atrazine, Total", "Desmetryn, Dissolved", "Desmetryn, Total", "Desthio-prothioconazole, Dissolved", "Diaminochlorotriazine (DACT), Not Recorded", "Diazinon oxon, Dissolved", "Diazinon oxon, Particulate", "Diazinon(Surrogate), Total", "Diazinon, Dissolved", "Diazinon, Not Recorded", "Diazinon, Particulate", "Diazinon, Total", "Diazoxon, Dissolved", "Diazoxon, Not Recorded", "Diazoxon, Particulate", "Dibromooctafluorobiphenyl(Surrogate), Total", "Dibromooctafluorobiphenyl, 4,4'-(Surrogate), Total", "Dibromooctafluorobiphenyl, 4,4'-(Surrogate)DB-608, Total", "Dibromooctafluorobiphenyl, 4,4'-(Surrogate)HP-5, Total", "Dibromooctafluorobiphenyl, 4-4'-(Surrogate), Total", "Dibutylchlorendate(Surrogate), Total", "Dichlofenthion(Surrogate), Total", "Dichlofenthion, Total", "Dichlone, Total", "Dichloran, Total", "Dichloroaniline, 3,5-, Dissolved", "Dichloroaniline, 3,5-, Particulate", "Dichlorobenzenamine, 3,4-, Dissolved", "Dichlorobenzenamine, 3,4-, Particulate", "Dichlorobenzenamine, 3,4-, Total", "Dichlorobenzophenone(p,p'), Total", "Dichlorophenyl Urea, 3,4-, Dissolved", "Dichlorophenyl Urea, 3,4-, Total", "Dichlorophenyl-3-methyl Urea, 3,4-, Dissolved", "Dichlorophenyl-3-methyl Urea, 3,4-, Total", "Dichlorvos, Not Recorded", "Dichlorvos, Total", "Dichrotophos, Total", "Dicofol, Total", "Dicrotophos, Total", "Dieldrin(Surrogate), Dissolved", "Dieldrin(Surrogate), Particulate", "Dieldrin(Surrogate), Total", "Dieldrin, Dissolved", "Dieldrin, Particulate", "Dieldrin, Total", "Diethatyl-Ethyl, Total", "Difenoconazole, Dissolved", "Difenoconazole, Particulate", "Diflubenzuron, Total", "Dimethoate, Not Recorded", "Dimethoate, Total", "Dimethomorph, Dissolved", "Dimethomorph, Particulate", "Dinotefuran, Dissolved", "Dioxathion, Total", "Diphenamid(Surrogate), Total", "Diphenamid, Dissolved", "Diphenamid, Total", "Diphenylamine, Total", "Dipropetryn, Dissolved", "Dipropetryn, Total", "Diquat, Total", "Disulfoton Sulfone, Total", "Disulfoton, Not Recorded", "Disulfoton, Total", "Dithiopyr, Dissolved", "Dithiopyr, Particulate", "Diuron, Dissolved", "Diuron, Not Recorded", "Diuron, Total", "Endosulfan I(Surrogate), Dissolved", "Endosulfan I(Surrogate), Particulate", "Endosulfan I(Surrogate), Total", "Endosulfan I, Dissolved", "Endosulfan I, Particulate", "Endosulfan I, Total", "Endosulfan I-d4(Surrogate), Dissolved", "Endosulfan I-d4(Surrogate), Particulate", "Endosulfan I-d4(Surrogate), Total", "Endosulfan II(Surrogate), Dissolved", "Endosulfan II(Surrogate), Particulate", "Endosulfan II(Surrogate), Total", "Endosulfan II, Dissolved", "Endosulfan II, Not Recorded", "Endosulfan II, Particulate", "Endosulfan II, Total", "Endosulfan Sulfate, Dissolved", "Endosulfan Sulfate, Not Recorded", "Endosulfan Sulfate, Particulate", "Endosulfan Sulfate, Total", "Endrin Aldehyde(Surrogate), Total", "Endrin Aldehyde, Total", "Endrin Ketone, Total", "Endrin Ketone-13C12(Surrogate), Total", "Endrin(Surrogate), Dissolved", "Endrin(Surrogate), Particulate", "Endrin(Surrogate), Total", "Endrin, Dissolved", "Endrin, Particulate", "Endrin, Total", "Endrin-13C12(Surrogate), Total", "EPN(Surrogate), Total", "EPN, Total", "EPTC(Surrogate), Total", "EPTC, Dissolved", "EPTC, Particulate", "EPTC, Total", "Esfenvalerate, Dissolved", "Esfenvalerate, Not Recorded", "Esfenvalerate, Particulate", "Esfenvalerate, Total", "Esfenvalerate/Fenvalerate, Total, Total", "Esfenvalerate/Fenvalerate-1, Total", "Esfenvalerate/Fenvalerate-2, Total", "Esfenvalerate-d6, Total(Surrogate), Total", "Esfenvalerate-d6-1(Surrogate), Total", "Esfenvalerate-d6-2(Surrogate), Total", "Ethaboxam, Dissolved", "Ethafluralin, Total", "Ethalfluralin, Dissolved", "Ethalfluralin, Not Recorded", "Ethalfluralin, Particulate", "Ethalfluralin, Total", "Ethion(Surrogate), Total", "Ethion, Total", "Ethoprop, Not Recorded", "Ethoprop, Total", "Famoxadone, Dissolved", "Famoxadone, Particulate", "Famphur, Total", "Fenamidone, Dissolved", "Fenamidone, Particulate", "Fenamiphos, Not Recorded", "Fenamiphos, Total", "Fenarimol, Dissolved", "Fenarimol, Particulate", "Fenbuconazole, Dissolved", "Fenbuconazole, Particulate", "Fenchlorphos, Total", "Fenhexamid, Dissolved", "Fenhexamid, Particulate", "Fenitrothion, Total", "Fenoxycarb, Not Recorded", "Fenpropathrin, Dissolved", "Fenpropathrin, Not Recorded", "Fenpropathrin, Particulate", "Fenpropathrin, Total", "Fenpropathrin-d6(Surrogate), Total", "Fenpyroximate, Dissolved", "Fenpyroximate, Particulate", "Fensulfothion, Total", "Fenthion, Dissolved", "Fenthion, Particulate", "Fenthion, Total", "Fenuron, Dissolved", "Fenuron, Total", "Fenvalerate, Total", "Fipronil Amide, Dissolved", "Fipronil Amide, Not Recorded", "Fipronil Amide, Total", "Fipronil Desulfinyl Amide, Dissolved", "Fipronil Desulfinyl Amide, Not Recorded", "Fipronil Desulfinyl Amide, Particulate", "Fipronil Desulfinyl Amide, Total", "Fipronil Desulfinyl, Dissolved", "Fipronil Desulfinyl, Not Recorded", "Fipronil Desulfinyl, Particulate", "Fipronil Desulfinyl, Total", "Fipronil Sulfide, Dissolved", "Fipronil Sulfide, Not Recorded", "Fipronil Sulfide, Particulate", "Fipronil Sulfide, Total", "Fipronil Sulfone, Dissolved", "Fipronil Sulfone, Not Recorded", "Fipronil Sulfone, Particulate", "Fipronil Sulfone, Total", "Fipronil, Dissolved", "Fipronil, Not Recorded", "Fipronil, Particulate", "Fipronil, Total", "Fipronil-13C4 15N2(Surrogate), Total", "Fipronil-C13(Surrogate), Dissolved", "Fipronil-C13(Surrogate), Particulate", "Flonicamid, Dissolved", "Fluazinam, Dissolved", "Fluazinam, Particulate", "Flucythrinate, Total", "Fludioxonil, Dissolved", "Fludioxonil, Particulate", "Flufenacet, Dissolved", "Flufenacet, Particulate", "Flumetralin, Dissolved", "Flumetralin, Particulate", "Fluometuron, Dissolved", "Fluometuron, Total", "Fluopicolide, Dissolved", "Fluopicolide, Particulate", "Fluopyram, Dissolved", "Fluopyram, Particulate", "Fluoxastrobin, Dissolved", "Fluoxastrobin, Particulate", "Fluridone(Surrogate), Dissolved", "Fluridone(Surrogate), Total", "Fluridone, Dissolved", "Fluridone, Total", "Flusilazole, Dissolved", "Flusilazole, Particulate", "Flutriafol, Dissolved", "Flutriafol, Particulate", "Fluvalinate, Total", "Fluxapyroxad, Dissolved", "Fluxapyroxad, Particulate", "Folpet, Total", "Fonofos, Not Recorded", "Fonofos, Total", "Galaxolide, Total", "Glyphosate, Dissolved", "Glyphosate, Not Recorded", "Glyphosate, Total", "Halosulfuron Methyl, Total", "HCH, alpha-(Surrogate), Total", "HCH, alpha-, Dissolved", "HCH, alpha-, Particulate", "HCH, alpha-, Total", "HCH, beta-(Surrogate), Dissolved", "HCH, beta-(Surrogate), Particulate", "HCH, beta-(Surrogate), Total", "HCH, beta-, Dissolved", "HCH, beta-, Particulate", "HCH, beta-, Total", "HCH, delta-(Surrogate), Dissolved", "HCH, delta-(Surrogate), Particulate", "HCH, delta-(Surrogate), Total", "HCH, delta-, Dissolved", "HCH, delta-, Particulate", "HCH, delta-, Total", "HCH, gamma-(Surrogate), Dissolved", "HCH, gamma-(Surrogate), Particulate", "HCH, gamma-(Surrogate), Total", "HCH, gamma-, Dissolved", "HCH, gamma-, Particulate", "HCH, gamma-, Total", "HCH, gamma-/PCB 015/18, Total", "HCH-d6, gamma-(Surrogate), Total", "Heptachlor Epoxide(Surrogate), Dissolved", "Heptachlor Epoxide(Surrogate), Particulate", "Heptachlor Epoxide(Surrogate), Total", "Heptachlor Epoxide, Dissolved", "Heptachlor Epoxide, Particulate", "Heptachlor Epoxide, Total", "Heptachlor Epoxide/Oxychlordane, Dissolved", "Heptachlor Epoxide/Oxychlordane, Particulate", "Heptachlor Epoxide/Oxychlordane, Total", "Heptachlor Epoxide-13C10(Surrogate), Total", "Heptachlor(Surrogate), Dissolved", "Heptachlor(Surrogate), Particulate", "Heptachlor(Surrogate), Total", "Heptachlor, Dissolved", "Heptachlor, Particulate", "Heptachlor, Total", "Heptachlor-13C10(Surrogate), Total", "Heptachlorobenzene, Total", "Hexachlorobenzene(Surrogate), Dissolved", "Hexachlorobenzene(Surrogate), Particulate", "Hexachlorobenzene(Surrogate), Total", "Hexachlorobenzene, Dissolved", "Hexachlorobenzene, Particulate", "Hexachlorobenzene, Total", "Hexachlorobenzene-13C6(Surrogate), Total", "Hexazinone, Dissolved", "Hexazinone, Not Recorded", "Hexazinone, Particulate", "Hexazinone, Total", "Hydramethylnon, Not Recorded", "Hydroxyatrazine, 2-, Dissolved", "Hydroxyatrazine, 2-, Total", "Hydroxycarbofuran, 3- , Dissolved", "Hydroxycarbofuran, 3- , Not Recorded", "Hydroxycarbofuran, 3- , Total", "Hydroxypropanal, 3-, Total", "Imazalil, Dissolved", "Imazalil, Particulate", "Imazalil, Total", "Imidacloprid guanidine olefin, Not Recorded", "Imidacloprid guanidine, Not Recorded", "Imidacloprid olefin, Not Recorded", "Imidacloprid urea, Not Recorded", "Imidacloprid-d4(Surrogate), Dissolved", "Indoxacarb, Dissolved", "Indoxacarb, Particulate", "Ipconazole, Dissolved", "Ipconazole, Particulate", "Isodrin, Total", "Isodrin-13C12(Surrogate), Total", "Isofenphos, Total", "Isoxaben, Total", "Jasmolin-1, Dissolved", "Jasmolin-1, Total", "Jasmolin-2, Dissolved", "Jasmolin-2, Total", "Kepone, Total", "Ketocarbofuran, 3-, Dissolved", "Leptophos, Total", "Linuron, Dissolved", "Linuron, Total", "Malaoxon, Dissolved", "Malaoxon, Not Recorded", "Malaoxon, Particulate", "Malathion, Dissolved", "Malathion, Not Recorded", "Malathion, Particulate", "Malathion, Total", "Mandipropamid, Dissolved", "MCPA, dimethylamine salt, Not Recorded", "Merphos, Total", "Methamidophos, Not Recorded", "Methamidophos, Total", "Methidathion oxon, Not Recorded", "Methidathion, Dissolved", "Methidathion, Not Recorded", "Methidathion, Particulate", "Methidathion, Total", "Methiocarb sulfone, Not Recorded", "Methiocarb sulfoxide, Not Recorded", "Methiocarb, Dissolved", "Methiocarb, Not Recorded", "Methiocarb, Total", "Methomyl, Dissolved", "Methomyl, Not Recorded", "Methomyl, Total", "Methoprene, Dissolved", "Methoprene, Particulate", "Methoprene, Total", "Methoxychlor(Surrogate), Total", "Methoxychlor, Dissolved", "Methoxychlor, Particulate", "Methoxychlor, Total", "Methoxychlor-d6(Surrogate), Total", "Methoxyfenozide, Dissolved", "Methoxyfenozide, Not Recorded", "Methoxy-methylsulfanylphosphoryl acetamide, N-, Not Recorded", "Methyl (3,4-dichlorophenyl)carbamate, Total", "Methyl paraoxon, Not Recorded", "Metolachlor ethanesulfonic acid, Not Recorded", "Metolachlor oxanilic acid, Not Recorded", "Mevinphos, Total", "Mexacarbate, Total", "Mirex(Surrogate), Dissolved", "Mirex(Surrogate), Particulate", "Mirex(Surrogate), Total", "Mirex, Dissolved", "Mirex, Particulate", "Mirex, Total", "Mirex-13C10(Surrogate), Total", "Molinate, Dissolved", "Molinate, Not Recorded", "Molinate, Particulate", "Molinate, Total", "Monocrotophos, Total", "Monuron, Total", "Naled, Total", "Napropamide, Dissolved", "Napropamide, Particulate", "Napropamide, Total", "Neburon, Dissolved", "Neburon, Total", "Nonachlor, cis-(Surrogate), Dissolved", "Nonachlor, cis-(Surrogate), Particulate", "Nonachlor, cis-(Surrogate), Total", "Nonachlor, cis-, Dissolved", "Nonachlor, cis-, Particulate", "Nonachlor, cis-, Total", "Nonachlor, trans-(Surrogate), Dissolved", "Nonachlor, trans-(Surrogate), Particulate", "Nonachlor, trans-(Surrogate), Total", "Nonachlor, trans-, Dissolved", "Nonachlor, trans-, Particulate", "Nonachlor, trans-, Total", "Norflurazon, Dissolved", "Norflurazon, Not Recorded", "Norflurazon, Total", "Novaluron, Dissolved", "Novaluron, Particulate", "Oxadiazon, Dissolved", "Oxadiazon, Particulate", "Oxadiazon, Total", "Oxamyl, Dissolved", "Oxamyl, Not Recorded", "Oxamyl, Total", "Oxychlordane(Surrogate), Dissolved", "Oxychlordane(Surrogate), Particulate", "Oxychlordane(Surrogate), Total", "Oxychlordane, Dissolved", "Oxychlordane, Particulate", "Oxychlordane, Total", "Oxychlordane-13C10(Surrogate), Total", "Oxyfluorfen, Dissolved", "Oxyfluorfen, Not Recorded", "Oxyfluorfen, Particulate", "Oxyfluorfen, Total", "Paclobutrazol, Dissolved", "Paclobutrazol, Particulate", "Paraoxon, Not Recorded", "Paraoxon, Total", "Paraquat, Total", "Parathion, Ethyl, Not Recorded", "Parathion, Ethyl, Total", "Parathion, Methyl, Dissolved", "Parathion, Methyl, Not Recorded", "Parathion, Methyl, Particulate", "Parathion, Methyl, Total", "PCNB, Dissolved", "PCNB, Particulate", "PCNB, Total", "Pebulate, Dissolved", "Pebulate, Particulate", "Pebulate, Total", "Pendimethalin, Dissolved", "Pendimethalin, Not Recorded", "Pendimethalin, Particulate", "Pendimethalin, Total", "Penoxsulam, Dissolved", "Penoxsulam, Total", "Perfluorobutanoate(Surrogate), Total", "Perfluorodecanoate(Surrogate), Total", "Perfluorododecanoate(Surrogate), Total", "Perfluorohexanoate(Surrogate), Total", "Perfluorononanoate(Surrogate), Total", "Perfluorooctanesulfonate 080(Surrogate), Total", "Perfluorooctanoate(Surrogate), Total", "Permethrin, cis-(Surrogate), Particulate", "Permethrin, cis-, Total", "Permethrin, Total, Dissolved", "Permethrin, Total, Particulate", "Permethrin, Total, Total", "Permethrin, trans-, Total", "Permethrin-13C6, cis-(Surrogate), Total", "Perthane, Total", "Phenothrin, Dissolved", "Phenothrin, Particulate", "Phenothrin, Total", "Phorate, Not Recorded", "Phorate, Total", "Phosalone Oxon, Not Recorded", "Phosalone, Not Recorded", "Phosalone, Total", "Phosmet, Dissolved", "Phosmet, Not Recorded", "Phosmet, Particulate", "Phosmet, Total", "Phosmet-Oxon, Not Recorded", "Phosphamidon, Total", "Picoxystrobin, Dissolved", "Picoxystrobin, Particulate", "Piperonyl Butoxide, Dissolved", "Piperonyl Butoxide, Particulate", "Piperonyl Butoxide, Total", "Pirimiphos Methyl, Total", "Prallethrin, Total", "Procymidone, Total", "Profenofos, Not Recorded", "Profenofos, Total", "Profluralin, Total", "Prometon, Dissolved", "Prometon, Not Recorded", "Prometon, Particulate", "Prometon, Total", "Prometryn, Dissolved", "Prometryn, Not Recorded", "Prometryn, Particulate", "Prometryn, Total", "Propachlor, Total", "Propanil, Dissolved", "Propanil, Not Recorded", "Propanil, Particulate", "Propanil, Total", "Propargite, Dissolved", "Propargite, Particulate", "Propargite, Total", "Propazine, Dissolved", "Propazine, Total", "Propham, Dissolved", "Propham, Total", "Propoxur, Dissolved", "Propoxur, Total", "Propyzamide, Dissolved", "Propyzamide, Particulate", "Pymetrozin, Total", "Pyrethrin-1, Dissolved", "Pyrethrin-1, Total", "Pyrethrin-2, Dissolved", "Pyrethrin-2, Total", "Pyridaben, Dissolved", "Pyridaben, Particulate", "Pyrimethanil, Dissolved", "Pyrimethanil, Particulate", "Pyriproxyfen, Not Recorded", "Quinoxyfen, Dissolved", "Quinoxyfen, Particulate", "Resmethrin, Dissolved", "Resmethrin, Not Recorded", "Resmethrin, Particulate", "Resmethrin, Total", "Safrotin, Total", "Secbumeton, Dissolved", "Secbumeton, Total", "Sedaxane, Dissolved", "Sedaxane, Particulate", "Siduron, Dissolved", "Siduron, Total", "Simazine(Surrogate), Dissolved", "Simazine(Surrogate), Total", "Simazine, Dissolved", "Simazine, Not Recorded", "Simazine, Particulate", "Simazine, Total", "Simetryn, Dissolved", "Simetryn, Total", "Sulfallate, Total", "Sulfotep, Total", "Tebufenozide, Not Recorded", "Tebupirimfos oxon, Dissolved", "Tebupirimfos oxon, Particulate", "Tebupirimfos, Dissolved", "Tebupirimfos, Particulate", "Tebuthiuron(Surrogate), Total", "Tebuthiuron, Dissolved", "Tebuthiuron, Not Recorded", "Tebuthiuron, Total", "Tedion, Total", "Tefluthrin, Dissolved", "Tefluthrin, Particulate", "Tefluthrin, Total", "Terbufos Sulfone, Total", "Terbufos, Total", "Terbuthylazine, Dissolved", "Terbuthylazine, Total", "Terbutryn, Dissolved", "Terbutryn, Total", "Tetrachloro-m-xylene(Surrogate), Dissolved", "Tetrachloro-m-xylene(Surrogate), Particulate", "Tetrachloro-m-xylene(Surrogate), Total", "Tetrachloro-m-xylene, Dissolved", "Tetrachloro-m-xylene, Particulate", "Tetrachloro-m-xylene, Total", "Tetrachlorvinphos, Total", "Tetradifon, Dissolved", "Tetradifon, Particulate", "Tetradifon, Total", "Tetraethyl Pyrophosphate, Total", "Tetramethrin, Dissolved", "Tetramethrin, Particulate", "Tetramethrin, Total", "T-Fluvalinate, Dissolved", "T-Fluvalinate, Particulate", "T-Fluvalinate, Total", "Thiacloprid, Dissolved", "Thiamethoxam, Dissolved", "Thiamethoxam, Total", "Thiazopyr, Dissolved", "Thiazopyr, Particulate", "Thiobencarb, Dissolved", "Thiobencarb, Not Recorded", "Thiobencarb, Particulate", "Thiobencarb, Total", "Thionazin, Total", "Thiram, Not Recorded", "Tokuthion, Total", "Tolfenpyrad, Dissolved", "Total Chlordanes, Total", "Total DDDs, Total", "Total DDEs, Total", "Total DDTs, Total", "Total HCHs, Total", "Total Pyrethrins, Total", "Toxaphene, Dissolved", "Toxaphene, Particulate", "Toxaphene, Total", "Tralomethrin, Total", "Triadimefon, Dissolved", "Triadimefon, Particulate", "Triadimenol, Dissolved", "Triadimenol, Particulate", "Triallate , Dissolved", "Triallate , Particulate", "Tributyl Phosphorotrithioate, S,S,S-, Dissolved", "Tributyl Phosphorotrithioate, S,S,S-, Not Recorded", "Tributyl Phosphorotrithioate, S,S,S-, Particulate", "Tributyl Phosphorotrithioate, S,S,S-, Total", "Tributylphosphate(Surrogate), Total", "Trichlorfon, Total", "Trichloronate, Total", "Triclopyr, Not Recorded", "Triclopyr, Total", "Tridimephon, Total", "Trifluralin-d14(Surrogate), Dissolved", "Trifluralin-d14(Surrogate), Particulate", "Triphenyl Phosphate(Surrogate), Dissolved", "Triphenyl Phosphate(Surrogate), Particulate", "Triphenyl Phosphate(Surrogate), Total", "Trithion, Methyl, Total", "Triticonazole, Dissolved", "Triticonazole, Particulate", "Vinclozolin, Total", "Zoxamide, Dissolved", "Zoxamide, Particulate", ]
WaterChem = FILES["WaterChemistryData"]
path, fileName = os.path.split(WaterChem)
newFileName = 'Pesticides_v2' + extension
column_filter = 'Analyte'
name, location, sitesname, siteslocation = selectByAnalyte(path=path, fileName=fileName, newFileName=newFileName, analytes=analytes,
		                field_filter=column_filter, sep=sep)
FILES[name] = location
FILES[sitesname] = siteslocation
print("\t\tFinished writing data subset for Pesticides_v2\n\n")
################### ^^^^^^^^^^^^^^^^^^^^^^^^^ END OF PESTICIDES_v2 ^^^^^^^^^^^^^^^^^^^^^^^^^^^^ ####################################


	if For_IR:
		RB = list(range(1, 10))
		# add check to see if For_RB folder exists in path location
		if not os.path.isdir(os.path.join(saveLocation, 'By_RB')):
			os.mkdir(os.path.join(saveLocation, 'By_RB'))
		for IR_file in FILES.values():
			if not os.path.isfile(IR_file):
				continue
			for Region in RB:
				path, fileName = os.path.split(IR_file)
				file_parts, ext = os.path.splitext(fileName)
				if file_parts == 'IR_STORET_2010' or file_parts == 'IR_STORET_2012' or file_parts == 'IR_NWIS':
					continue
				newFileName = 'By_RB\\' + file_parts + '_RB_' + str(Region) + ext
				if file_parts == 'IR_ToxicityData' or file_parts == 'IR_Field':
					column_filter = 'RegionalBoard'
				else:
					column_filter = 'RegionalBoardID'
				analytes = [str(Region), ]
				name, location, sitesname = selectByAnalyte(path=path, fileName=fileName, newFileName=newFileName,
				                analytes=analytes, field_filter=column_filter, sep=sep, For_IR=True)
				#FILES[name] = location
				#FILES[sitesname] = siteslocation
				print('Completed %s' % newFileName)


	##########################################################################################################
	##########################################################################################################
	############### ####       Upload to Data.ca.gov section            ######################################
	##########################################################################################################
	##########################################################################################################


	if not For_IR:
		#### upload dataset to data.ca.gov
		print("Starting to upload files to Data.ca.gov")
		user = os.environ.get('DCG_user')
		password = os.environ.get('DCG_pw')
		URI = os.environ.get('URI')
		api = DatasetAPI(URI, user, password, debug=False)
		# the uploads variable is a dictionary that needs a file path and the Node # from data.ca.gov
		# The FILES object has the file path information and we use it as a key for the Node # in the for loop below.
		uploads = {FILES['BenthicData']: 431, FILES['ToxicityData']: 541, FILES['All_CEDEN_Sites']: 2331,
		           FILES['TissueData_prior_to_1999']: 2366, FILES['TissueData_2000-2009']: 2361,
		           FILES['TissueData_2010-present']: 2086, FILES['HabitatData_prior_to_1999']: 2376,
		           FILES['HabitatData_2000-2009']: 2371, FILES['HabitatData_2010-present']: 2036,
		           FILES['WaterChemistryData_prior_to_1999']: 2386, FILES['SafeToSwim.csv']: 2396,
		           FILES['Sites_for_SafeToSwim.csv']: 2401, }

		# Troubles shooting lines below
		#FILES['WaterChemistryData_2000-2009']: 2381, FILES['WaterChemistryData_2010-present']: 2326,
		#uploads = {'C:\\Users\\AHill\\Documents\\CEDEN_Datasets\\WaterChemistryData_2000-2009.csv': 2381, }

		# Waiting to add these to the automatic uploading above because of uploading size limits:
		# FILES['WaterChemistryData_2000-2009']: 2381, FILES['WaterChemistryData_2010-present']: 2326,
		# FILES['SafeToSwim.csv']: 2186, FILES['Sites_for_SafeToSwim.csv']: 2181,
        
		# uploads = {FILES['HabitatData_2010-present']: 2036}    

		for file in uploads:
			print("Starting to upload %s to Data.ca.gov" % os.path.basename(file))
			r = api.attach_file_to_node(file=file, node_id=uploads[file], field='field_upload', update=0)
			if r.ok:
				print("Completed uploading %s to data.ca.gov" % os.path.split(file)[1])
				r.close()
				del r
			else:
				print("something went wrong\n")
				print("with %s. Here is the response error code: %s " % (os.path.split(file)[1], r.status_code))
				print("\nAlso, here is the response text")
				print(r.text)
				print(r.reason)
				r.close()
				del r
