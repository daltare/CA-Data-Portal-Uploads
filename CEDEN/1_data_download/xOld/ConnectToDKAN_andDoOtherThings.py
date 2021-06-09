import os, csv
import json 
from dkan.client import DatasetAPI
import numpy as np
import pandas as pd


user = os.environ.get('DCG_user')
password = os.environ.get('DCG_pw')
URI= os.environ.get('URI')


#uri = os.environ.get('URI', False)
#uri = 'https://test.cadepttech.nucivicdata.com/node/1826/api'
#uri = 'https://test.cadepttech.nucivicdata.com/dataset/flow-targets-southern-california-streams/resource/d2f2657c-1fb4-4ae2-a31b-d4b80ccee3e8'
#uri = 'https://test.cadepttech.nucivicdata.com/api/action/datastore/search.json?resource_id=d2f2657c-1fb4-4ae2-a31b-d4b80ccee3e8'
#uri = 'https://data.ca.gov/node/1691/api'
#URI = 'https://data.ca.gov/'
#uriNode1721Test = 'https://data.ca.gov/api/dataset/node/1721'
#uri = 'https://test.cadepttech.nucivicdata.com/'


#with DatasetAPI(uri, user, password , True) as api:
#	print(api.node('index'))

# gives a list of anything available but on 20....!!!! 
onA="on"
if onA:
	api = DatasetAPI(URI, user, password , True)
	r = api.node('index' )
	#print(r.json())
	columns = [desc for desc in r.json()[0]]
	rStack=np.vstack(r.json())
	df2 = pd.DataFrame(data=r.json(), columns=columns)
	print(df2)
	#df.to_csv("outTestTrash.csv", sep=',', encoding='utf-8')
else:
	print("BooHoo")
	
	
	

# only use to list dataset from 
on="on"
if on:
	api = DatasetAPI(URI, user, password , True)
	
	# List datasets 
	params = { 
		'parameters[type]': 'dataset', 
	}
	r = api.node(params=params)
	#print(r.json())
	columns = [desc for desc in r.json()[0]]
	rStack=np.vstack(r.json())
	df = pd.DataFrame(data=r.json(), columns=columns)
	print(df)
	#df.to_csv("outTestTrash.csv", sep=',', encoding='utf-8')
else:
	print("BooHoo")

	

# only use to list resources
onB="on"
if onB:
	api = DatasetAPI(URI, user, password , True)
	
	# List datasets 
	params = { 
		'parameters[type]': 'resource', 
	}
	r = api.node(params=params)
	#print(r.json())
	columns = [desc for desc in r.json()[0]]
	rStack=np.vstack(r.json())
	df3 = pd.DataFrame(data=r.json(), columns=columns)
	print(df3)
	#df.to_csv("outTestTrash.csv", sep=',', encoding='utf-8')
else:
	print("BooHoo")	

	
	
#Dataset 1821 is the Data Automation testing ground at data.ca.gov/
	#Resource associated with 1821 is 1826
	
	
# to create a resource!!!
on1="on"
if on1:
	api = DatasetAPI(URI, user, password , True)
	print("Creating dataset")
	data = { 
		'title': 'Test Creation of resource associated with Data Automation Dataset ',
		'type': 'resource',
		'field_dataset_ref': { 'und': { 'target_id': 1821} }
	}
	dataset = api.node('create', data=data)
	print(dataset.status_code )
	print(dataset.text )
else:
	print(" Create dataset not turned on")


	
	
# to get info about parent dataset  which will give us the group information.
on2="on"
if on2:
	api = DatasetAPI(URI, user, password , True)
	# Get attributes of dataset 
	#print('Getting Dataset Attributes') 
	r = api.node('retrieve', node_id='1826') 


# Update dataset title 
onC ="on"
if onC:
	data = { 
		'title': '' 
	}
	r = api.node(action = 'update', node_id='1826', data=data) 
	print( 'Response: %s\n\n' % r.text )
	r = api.node('retrieve', node_id='1826') 
	print(r.json())

# Attach dataset data 
onC1 ="on"
if onC1:
	#csv = os.path.join(os.path.dirname(os.path.abspath(__file__)), '.', 'data', 'tension_sample_data.csv') 
	csv1 = "C:\Users\AHill\Documents\PythonScripts\TestDatSet_trash.csv"
	
	r = api.attach_file_to_node(file = csv1, node_id='1826', field = 'field_upload' )
	print( 'Response: %s\n\n' % r.text )
	r = api.node('retrieve', node_id='1826') 
	print(r.json())




