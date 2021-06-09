import click
# import json
import math
import os
import requests
from requests_toolbelt import MultipartEncoder, MultipartEncoderMonitor

from datetime import date #, timedelta
today = str(date.today())
# today = '2021-06-01'


####### CONFIGURE CKAN PARAMETERS #######
ckan_base = 'https://data.ca.gov'
ckan_api_key = os.environ.get('data_portal_key')
####### END OF CKAN PARAMTER CONFIGURATION #######


####### DAA - CONFIGURE UPLOAD FILES LOCATION AND LIST #######
# upload_files_location = 'C:/David/Open_Data_Project/__CA_DataPortal/'
upload_files_location = 'C:\\Users\\daltare\\OneDrive - Water Boards\\projects\\CA_data_portal\\SMARTS\\'

uploads = {
# industrial
'Industrial_Ad_Hoc_Reports_-_Parameter_Data_' + today + '.csv': '7871e8fe-576d-4940-acdf-eca0b399c1aa',
'Industrial_Application_Specific_Data_' + today + '.csv': '33e69394-83ec-4872-b644-b9f494de1824',
# construction
'Construction_Ad_Hoc_Reports_-_Parameter_Data_' + today + '.csv': '0c441948-5bb9-4d50-9f3c-ca7dab256056',
'Construction_Application_Specific_Data_' + today + '.csv': '8a0ed456-ca69-4b29-9c5b-5de3958dc963',
# enforcement
'Enforcement_Actions_' + today + '.csv': '9cf197f4-f1d5-4d43-b94b-ccb155ef14cf',
# inspections
'Inspections_' + today + '.csv': '33047e47-7d44-46aa-9e0f-1a0f1b0cad66',
# violations
'Violations_' + today + '.csv': '9b69a654-0c9a-4865-8d10-38c55b1b8c58'
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
