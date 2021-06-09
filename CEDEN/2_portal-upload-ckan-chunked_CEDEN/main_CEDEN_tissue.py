import click
# import json
import math
import os
import requests
from requests_toolbelt import MultipartEncoder, MultipartEncoderMonitor

from datetime import date #, timedelta
# today = str(date.today())
today = '2021-06-01'


####### CONFIGURE CKAN PARAMETERS #######
ckan_base = 'https://data.ca.gov'
ckan_api_key = os.environ.get('data_portal_key')
####### END OF CKAN PARAMTER CONFIGURATION #######


####### DAA - CONFIGURE UPLOAD FILES LOCATION AND LIST #######
upload_files_location = 'C:\\David\\_CA_data_portal\\CEDEN\\CEDEN_Datasets' + today + '\\'
# upload_files_location = 'C:\\Users\\daltare\\OneDrive - Water Boards\\projects\\CA_data_portal\\CEDEN\\1_data_download\\CEDEN_Datasets\\' + today + '/'

uploads = {
# tissue
#'TissueData_year-2021' + '_' + today + '.csv': ,
'TissueData_year-2020' + '_' + today + '.csv': 'a3545e8e-2ab5-46b3-86d5-72a74fcd8261',
'TissueData_year-2019' + '_' + today + '.csv': 'edd16b08-3d9f-4375-9396-dce7cbd2f717',
'TissueData_year-2018' + '_' + today + '.csv': '559c5523-8883-4da0-9750-f7fd3f088cfb',
'TissueData_year-2017' + '_' + today + '.csv': 'e30e6266-5978-47f4-ae6a-94336ab224f9',
'TissueData_year-2016' + '_' + today + '.csv': 'c7a56123-8692-4d92-93cc-aa12d7ab46c9',
'TissueData_year-2015' + '_' + today + '.csv': '3376163c-dcda-4b76-9672-4ecfee1e1417',
'TissueData_year-2014' + '_' + today + '.csv': '8256f15c-8500-47c3-be34-d12b45b0bbe9',
'TissueData_year-2013' + '_' + today + '.csv': 'eb2d102a-ecdc-4cbe-acb9-c11161ac74b6',
'TissueData_year-2012' + '_' + today + '.csv': '8e3bbc50-dd72-4cee-b926-b00f488ff10c',
'TissueData_year-2011' + '_' + today + '.csv': '06440749-3ada-4461-959f-7ac2699faeb0',
'TissueData_year-2010' + '_' + today + '.csv': '82dbd8ec-4d59-48b5-8e10-ce1e41bbf62a',
'TissueData_year-2009' + '_' + today + '.csv': 'c1357d10-41cb-4d84-bd3a-34e18fa9ecdf',
'TissueData_year-2008' + '_' + today + '.csv': 'da39833c-9d62-4307-a93e-2ae8ad2092e3',
'TissueData_year-2007' + '_' + today + '.csv': 'f88461cf-49b2-4c5c-ba2c-d9484202bc74',
'TissueData_year-2006' + '_' + today + '.csv': 'f3ac3204-f0a2-4561-ae18-836b8aafebe8',
'TissueData_year-2005' + '_' + today + '.csv': '77daaca9-3f47-4c88-9d22-daf9f79e2729',
'TissueData_year-2004' + '_' + today + '.csv': '1dc7ed28-a59b-48a7-bc81-ef9582a4efaa',
'TissueData_year-2003' + '_' + today + '.csv': '1a21e2ac-a9d8-4e81-a6ad-aa6636d064d1',
'TissueData_year-2002' + '_' + today + '.csv': '6a56b123-9275-4549-a625-e5aa6f2b8b57',
'TissueData_year-2001' + '_' + today + '.csv': '47df34fd-8712-4f72-89ff-091b3e954399',
'TissueData_year-2000' + '_' + today + '.csv': '06b35b3c-6338-44cb-b465-ba4c1863b7c5',
'TissueData_prior_to_2000' + '_' + today + '.csv': '97786a54-1189-43e4-9244-5dcb241dfa58',
}


####### END OF UPLOAD FILES CONFIGURATION #######

chunk_size = 1024 * 1024 * 64 # 64MB


# Post request to CKAN action API
def ckanRequest(action, data_dict):
    encoder = MultipartEncoder(fields=data_dict)
    callback = getCallback(encoder)
    monitor = MultipartEncoderMonitor(encoder, callback)
    try:
        r = requests.post(
                '{ckan_base}/api/action/{action}'.format(ckan_base=ckan_base, action=action),
                data=monitor,
                headers={
                    'Content-Type' : monitor.content_type,
                    'X-CKAN-API-Key': ckan_api_key
                }
            )
        return r.json()
    except:
        #print(r.text)
        print('error') # DA - Added this line
        return


def getCallback(encoder):
    prog = click.progressbar(length=encoder.len, width=0)

    def callback(monitor):
        prog.pos = monitor.bytes_read
        prog.update(0)

    return callback


# Read file in chunks
def readInChunks(file_object, chunk_size=chunk_size):
    while True:
        data = file_object.read(chunk_size)
        if not data:
            break
        yield data


def ckanUploadFile(resource_id, file_path):
    file_name = os.path.basename(file_path)
    file_size = os.path.getsize(file_path)

    chunk_count = math.ceil(float(file_size) / chunk_size)
    part_number = 1

    # Initiate multipart upload to get upload_id
    init_dict = {
        'id': resource_id,
        'name': file_name,
        'size': str(file_size)
    }
    init_response = ckanRequest('cloudstorage_initiate_multipart', init_dict)
    if init_response.get('success'):
        print('Ready to upload {0}\n{1} chunks\n'.format(file_name, chunk_count))
    else:
        print('Unable to initiate multipart upload')
        return
    upload_id = init_response.get('result', {}).get('id')

    # Read file and upload in chunks
    with open(file_path, 'rb') as upload_file:
        for chunk in readInChunks(upload_file):
            upload_dict = {
                'id': resource_id,
                'uploadId': upload_id,
                'partNumber': str(part_number),
                'upload': (file_name, chunk, 'text/plain')
            }
            print('Uploading chunk {}'.format(part_number))
            upload_response = ckanRequest('cloudstorage_upload_multipart', upload_dict)
            if upload_response.get('success'):
                print('Chunk {} sent to server\n'.format(part_number))
                part_number += 1
            else:
                print('Error uploading chunk {}'.format(part_number))
                return

    # Finish upload by converting separate uploaded parts into single file
    finish_dict = {
        'uploadId': upload_id,
        'id': resource_id,
        'save_action': 'go-metadata'
    }
    finish_response = ckanRequest('cloudstorage_finish_multipart', finish_dict)
    if finish_response.get('success'):
        print('All chunks sent to server')
    else:
        print('Error finalizing uploading chunk')
        return

    # Update resource
    data_dict = {
        'id': resource_id,
        'multipart_name': file_name,
        'url': file_name,
        'size': str(file_size),
        'url_type': 'upload'
    }
    res_update_response = ckanRequest('resource_patch', data_dict)
    if res_update_response.get('success'):
        print('Resource has been updated.')
        print(res_update_response)
    else:
        print('Unable to finish multipart upload')
        return

    return




#### MAIN FUNCTION ###
#if __name__ == "__main__":
#    # Resource id of existing CKAN resource
#    resource_id = 'feb79718-52b6-4aed-8f02-1493e6187294'
#
#
#    # File path of file to upload to CKAN
#    # file_path = '/Users/jayguo/Documents/waterchemistrydata_prior_to_2000_2019-12-03.csv'
#    file_path = 'C:/Users/daltare/Desktop/DELETE/WaterChemistryData_2000-2009_2020-01-15_2.csv'
#    ckanUploadFile(resource_id, file_path)


# Loop
### MAIN FUNCTION ###
if __name__ == "__main__":
    for file in uploads:
        # Resource id of existing CKAN resource
        resource_id = uploads[file]

        # File path of file to upload to CKAN
        # file_path = '/Users/jayguo/Documents/waterchemistrydata_prior_to_2000_2019-12-03.csv'
        file_path = upload_files_location + file
        ckanUploadFile(resource_id, file_path)
