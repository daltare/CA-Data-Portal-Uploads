'''

Author:
	Andrew Dix Hill; https://github.com/AndrewDixHill/CEDEN_to_DataCAGov ; andrew.hill@waterboards.ca.gov

Agency:
	California State Water Resource Control Board (SWRCB)
	Office of Information Management and Analysis (OIMA)

Purpose:
	This script will query an internal WaterBoard dataMart for Fresh Water Harmful Algal Bloom data only. It will
	filter all data for a set of printable characters and then publish the data to a resource node on data.ca.gov.
	It will convert positive longitude values to negative and replace Latitude or Longitude values that only only
	empty spaces. The file extension and delimiters are chosen specificaly to work with data.ca.gov's preview
	function.

How to use this script:
	You must be connected to the internal waternet
	From a powershell prompt (windows), call python and specify
	the complete path to this file. Below is an example, where XXXXXXX should be replaced
	with the filename:
	python C:\\Users\\User***\\Downloads\\XXXXXXX.py
	You must also set the SERVER, UID as environmental variables in your windows account
	You may also have to set the SQL driver on the pyodbc.connect line to your available drivers.
		Use pyodbc.drivers() to see a list of available drivers.

Prerequisites:
	Windows platform (not strictly a requirement but I was unable to get the pyodbc library
		working on a mac... I tried)
	Python 3.X
	pyodbc library for python.  See https://github.com/mkleehammer/pyodbc
	dkan library for python.    See https://github.com/GetDKAN/pydkan
	ODBC Driver 11 for SQL Server, Microsoft product downloaded here: https://www.microsoft.com/en-us/download/details.aspx?id=36434


'''

# Import the necessary libraries of python code
import pyodbc
import os
import csv
import re
from datetime import datetime
import string
from dkan.client import DatasetAPI
import getpass

# decodeAndStrip takes a string and filters each character through the printable variable. It returns a filtered string.
def decodeAndStrip(t):
	filter1 = ''.join(filter(lambda x: x in printable, str(t)))
	return filter1

if __name__ == "__main__":
	###########################
	############   Set these up for your computer ##########
	###########################
	SERVER = os.environ.get('FHAB_Server')
	UID = os.environ.get('FHAB_User')
	###########################
	############   Set these up for your computer##########
	###########################
	user = os.environ.get('DCG_user')
	password = os.environ.get('DCG_pw')
	URI = os.environ.get('URI')
	###########################
	############   CHange these ##########
	###########################
	printable = set(string.printable) - set('|"\`\t\r\n\f\v')
	### you can change this to point to a different location
	first = 'C:\\Users\\%s\\Documents' % getpass.getuser()
	path = os.path.join(first, 'FHAB_BloomReport')
	if not os.path.isdir(path):
		os.mkdir(path)
	### name of output file
	FHAB = 'FHAB_BloomReport'
	###   Ideally data.ca.gov will be able to generate data preview for tab delimited txt files... until then
	### extension type. Data.ca.gov requires csv for preview functionality
	ext = '.csv'
	### delimiter type.
	sep = ','
	file = os.path.join(path, FHAB + ext)
	cnxn = pyodbc.connect(Driver='ODBC Driver 11 for SQL Server', Server=SERVER, uid=UID, Trusted_Connection='Yes')
	cursor = cnxn.cursor()
	sql = "SELECT dbo.AlgaeBloomReport.AlgaeBloomReportID, dbo.AlgaeBloomReport.RegionalBoardID, dbo.AlgaeBloomReport.CountyID," \
	      " dbo.AlgaeBloomReport.Latitude, dbo.AlgaeBloomReport.Longitude, dbo.AlgaeBloomReport.ObservationDate, CASE WHEN " \
	      "HasPostedSigns = 1 THEN 'Yes' ELSE 'No' END AS HasPostedSigns, CASE WHEN HasContactWithWater = 1 THEN 'Yes' ELSE 'No' " \
	      "END AS HasContactWithWater, dbo.AlgaeBloomReport.WaterBodyType, dbo.AlgaeBloomReport.WaterBodyName, " \
	      "dbo.AlgaeBloomReport.WaterBodyManager, dbo.AlgaeBloomReport.RecLandManager, CASE WHEN IsIncidentResoloved = 1 THEN 'Yes'" \
	      " ELSE 'No' END AS IsIncidentResoloved, dbo.AlgaeBloomReport.IncidentInformation, dbo.AlgaeBloomReport.TypeofSign, " \
	      "dbo.AlgaeBloomReport.OfficialWaterBodyName, dbo.AlgaeBloomReport.BloomLastVerifiedOn, dbo.AlgaeBloomReport.BloomDeterminedBy, " \
	      "dbo.AlgaeBloomReport.ApprovedforPost FROM (dbo.AlgaeBloomReport INNER JOIN dbo.County ON dbo.AlgaeBloomReport.CountyID = dbo.County.CountyID) " \
         "INNER JOIN dbo.RegionalBoard ON dbo.AlgaeBloomReport.RegionalBoardID = dbo.RegionalBoard.RegionalBoardID " \
	      "WHERE (((dbo.AlgaeBloomReport.ApprovedforPost)= 1))"
	cursor.execute(sql)
	columns = [desc[0] for desc in cursor.description]
	with open(file, 'w', newline='', encoding='utf8') as writer:
		dw = csv.DictWriter(writer, fieldnames=columns, delimiter=sep, lineterminator='\n')
		dw.writeheader()
		FHAB_writer = csv.writer(writer, csv.QUOTE_MINIMAL, delimiter=sep, lineterminator='\n')
		for row in cursor:
			row = [str(word) if word is not None else '' for word in row]
			filtered = [decodeAndStrip(t) for t in list(row)]
			newDict = dict(zip(columns, filtered))
			try:
				long = float(newDict['Longitude'])
				if long > 0:
					newDict['Longitude'] = -long
			except ValueError:
				pass
			FHAB_writer.writerow(list(newDict.values()))
	# 2156 FHAB portal data
	NODE = 2156
	api = DatasetAPI(URI, user, password, debug=False)
	r = api.attach_file_to_node(file=file, node_id=NODE, field='field_upload', update=0)