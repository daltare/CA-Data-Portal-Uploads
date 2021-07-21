import click
# import json
import math
import os
import requests
from requests_toolbelt import MultipartEncoder, MultipartEncoderMonitor

from datetime import date #, timedelta
# today = str(date.today())
today = '2021-07-19'


####### CONFIGURE CKAN PARAMETERS #######
ckan_base = 'https://data.ca.gov'
ckan_api_key = os.environ.get('data_portal_key')
####### END OF CKAN PARAMTER CONFIGURATION #######


####### DAA - CONFIGURE UPLOAD FILES LOCATION AND LIST #######
upload_files_location = 'C:\\David\\_CA_data_portal\\CEDEN\\CEDEN_Datasets\\' + today + '\\'
# upload_files_location = 'C:\\Users\\daltare\\OneDrive - Water Boards\\projects\\CA_data_portal\\CEDEN\\1_data_download\\CEDEN_Datasets\\' + today + '/'

uploads = {
# habitat
'HabitatData_year-2021' + '_' + today + '.csv': 'c82a3e83-a99b-49d8-873b-a39640b063fc',
'HabitatData_year-2020' + '_' + today + '.csv': 'bd37df2e-e6a4-4c2b-b01c-ce7840cc03de',
'HabitatData_year-2019' + '_' + today + '.csv': 'c0f230c5-3f51-4a7a-a3db-5eb8692654aa',
'HabitatData_year-2018' + '_' + today + '.csv': 'd814ca0c-ace1-4cc1-a80f-d63f138e2f61',
'HabitatData_year-2017' + '_' + today + '.csv': 'f7a33584-510f-46f8-a314-625f744ecbdd',
'HabitatData_year-2016' + '_' + today + '.csv': '01e35239-6936-4699-b9db-fda4751be6e9',
'HabitatData_year-2015' + '_' + today + '.csv': '115c55e3-40af-4734-877f-e197fdae6737',
'HabitatData_year-2014' + '_' + today + '.csv': '082a7665-8f54-4e4f-9d24-cc3506bb8f3e',
'HabitatData_year-2013' + '_' + today + '.csv': '3be276c3-9966-48de-b53a-9a98d9006cdb',
'HabitatData_year-2012' + '_' + today + '.csv': '78d44ee3-65af-4c83-b75e-8a82b8a1db88',
'HabitatData_year-2011' + '_' + today + '.csv': '2fa6d874-1d29-478a-a5dc-0c2d31230705',
'HabitatData_year-2010' + '_' + today + '.csv': '2a8b956c-38fa-4a15-aaf9-cb0fcaf915f3',
'HabitatData_year-2009' + '_' + today + '.csv': 'd025552d-de5c-4f8a-b2b5-a9de9e9c86c3',
'HabitatData_year-2008' + '_' + today + '.csv': 'ce211c51-05a2-4a7c-be18-298099a0dcd2',
'HabitatData_year-2007' + '_' + today + '.csv': '1659a2b4-21e5-4fc4-a9a4-a614f0321c05',
'HabitatData_year-2006' + '_' + today + '.csv': '88b33d5b-5428-41e2-b77b-6cb46ca5d1e4',
'HabitatData_year-2005' + '_' + today + '.csv': '1609e7ab-d913-4d24-a582-9ca7e8e82233',
'HabitatData_year-2004' + '_' + today + '.csv': 'e5132397-69a5-46fb-b24a-cd3b7a1fe53a',
'HabitatData_year-2003' + '_' + today + '.csv': '899f3ebc-538b-428e-8f1f-d591445a847c',
'HabitatData_year-2002' + '_' + today + '.csv': 'a9d8302d-0d37-4cf3-bbeb-386f6bd948a6',
'HabitatData_year-2001' + '_' + today + '.csv': 'ea8b0171-e226-4e80-991d-50752abea734',
'HabitatData_year-2000' + '_' + today + '.csv': 'b3dba1ee-6ada-42d5-9679-1a10b44630bc',
'HabitatData_prior_to_2000' + '_' + today + '.csv': 'a3dcc442-e722-495f-ad59-c704ae934848'
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
