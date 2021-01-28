import click
import json
import math
import os
import requests
from requests_toolbelt import MultipartEncoder, MultipartEncoderMonitor

from datetime import date #, timedelta
today = str(date.today())


####### CONFIGURE CKAN PARAMETERS #######
ckan_base = 'https://data.ca.gov'
ckan_api_key = os.environ.get('data_portal_key')
####### END OF CKAN PARAMTER CONFIGURATION #######


####### DAA - CONFIGURE UPLOAD FILES LOCATION AND LIST #######
upload_files_location = 'C:/David/Open_Data_Project/__CA_DataPortal/CEDEN/Python_Script/CEDEN_Datasets/portal-formatted/' + today + '/'
uploads = {'All_CEDEN_Sites' + '_' + today + '.csv': 'a927cb45-0de1-47e8-96a5-a5290816797b', 
           'SafeToSwim' + '_' + today + '.csv': 'fd2d24ee-3ca9-4557-85ab-b53aa375e9fc', 
           'Sites_for_SafeToSwim' + '_' + today + '.csv': '4f41c529-a33f-4006-9cfc-71b6944cb951',
           'BenthicData' + '_' + today + '.csv': '3dfee140-47d5-4e29-99ae-16b9b12a404f', 
           'HabitatData_prior_to_2000' + '_' + today + '.csv': '1eef884f-9633-45e0-8efb-09d48333a496',
           'HabitatData_2000-2009' + '_' + today + '.csv': '5bc866af-c176-463c-b513-88f536d69a28',
           'HabitatData_2010-present' + '_' + today + '.csv': 'fe54c1c5-c16b-4507-8b3b-d6563df98e95',
           'TissueData_prior_to_2000' + '_' + today + '.csv': 'ed646127-50e1-4163-8ff6-d30e8b8056b1', 
           'TissueData_2000-2009' + '_' + today + '.csv': '6890b717-19b6-4b1f-adfb-9c2874c8012e',
           'TissueData_2010-present' + '_' + today + '.csv': '5d4d572b-004b-4e2b-b26c-20ef050c018f', 
           'ToxicityData' + '_' + today + '.csv': 'bd484e9b-426a-4ba6-ba4d-f5f8ce095836',
           'WaterChemistryData_prior_to_2000' + '_' + today + '.csv': '158c8ca1-b02f-4665-99d6-2c1c15b6de5a', 
           'WaterChemistryData_2000-2009' + '_' + today + '.csv': 'feb79718-52b6-4aed-8f02-1493e6187294', 
           'WaterChemistryData_2010-present' + '_' + today + '.csv': 'afaeb2b2-e26f-4d18-8d8d-6aade151b34a',}
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
        print(r.text)
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
