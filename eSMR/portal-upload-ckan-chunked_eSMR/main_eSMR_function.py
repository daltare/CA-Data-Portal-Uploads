import click
import json
import math
import os
import requests
from requests_toolbelt import MultipartEncoder, MultipartEncoderMonitor

from datetime import date #, timedelta
# today = str(date.today())
# today = "2021-09-09"


####### CONFIGURE CKAN PARAMETERS #######
ckan_base = 'https://data.ca.gov'
# ckan_api_key = os.environ.get('data_portal_key')
####### END OF CKAN PARAMTER CONFIGURATION #######


####### DAA - CONFIGURE UPLOAD FILES LOCATION AND LIST #######
# upload_files_location = 'C:/David/_CA_data_portal/Surface-Water-Datasets/esmr/'
# uploads = {'esmr_analytical_export_year-2021' + '_' + today + '.csv': '28d3a164-7cec-4baf-9b11-7a9322544cd6',  
           # 'esmr_analytical_export_year-2020' + '_' + today + '.csv': '4fa56f3f-7dca-4dbd-bec4-fe53d5823905',
		   # 'esmr_analytical_export_year-2019' + '_' + today + '.csv': '2eaa2d55-9024-431e-b902-9676db949174',
           # 'esmr_analytical_export_year-2018' + '_' + today + '.csv': 'bb3b3d85-44eb-4813-bbf9-ea3a0e623bb7',
           # 'esmr_analytical_export_year-2017' + '_' + today + '.csv': '44d1f39c-f21b-4060-8225-c175eaea129d',
           # 'esmr_analytical_export_year-2016' + '_' + today + '.csv': 'aacfe728-f063-452c-9dca-63482cc994ad',
		   # 'esmr_analytical_export_year-2015' + '_' + today + '.csv': '81c399d4-f661-4808-8e6b-8e543281f1c9',
		   # 'esmr_analytical_export_year-2014' + '_' + today + '.csv': 'c0f64b3f-d921-4eb9-aa95-af1827e5033e',
		   # 'esmr_analytical_export_year-2013' + '_' + today + '.csv': '8fefc243-9131-457f-b180-144654c1f481',
		   # 'esmr_analytical_export_year-2012' + '_' + today + '.csv': '67fe1c01-1c1c-416a-92e1-ee8437db615a',
		   # 'esmr_analytical_export_year-2011' + '_' + today + '.csv': 'c495ca93-6dbe-4b23-9d17-797127c28914',
		   # 'esmr_analytical_export_year-2010' + '_' + today + '.csv': '4eb833b3-f8e9-42e0-800e-2b1fe1e25b9c',
		   # 'esmr_analytical_export_year-2009' + '_' + today + '.csv': '3607ae5c-d479-4520-a2d6-3112cf92f32f',
		   # 'esmr_analytical_export_year-2008' + '_' + today + '.csv': 'c0e3c8be-1494-4833-b56d-f87707c9492c',
		   # 'esmr_analytical_export_year-2007' + '_' + today + '.csv': '7b99f591-23ac-4345-b645-9adfaf5873f9',
		   # 'esmr_analytical_export_year-2006' + '_' + today + '.csv': '763e2c90-7b7d-412e-bbb5-1f5327a5f84e',
		   # }
####### END OF UPLOAD FILES CONFIGURATION #######

chunk_size = 1024 * 1024 * 64 # 64MB


# Post request to CKAN action API
def ckanRequest(action, data_dict, ckan_api_key):
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


def ckanUploadFile(resource_id, file_path, ckan_api_key):
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
    init_response = ckanRequest('cloudstorage_initiate_multipart', init_dict, ckan_api_key)
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
            upload_response = ckanRequest('cloudstorage_upload_multipart', upload_dict, ckan_api_key)
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
    finish_response = ckanRequest('cloudstorage_finish_multipart', finish_dict, ckan_api_key)
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
    res_update_response = ckanRequest('resource_patch', data_dict, ckan_api_key)
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
# if __name__ == "__main__":
    # for file in uploads:
        # # Resource id of existing CKAN resource
        # resource_id = uploads[file]

        # # File path of file to upload to CKAN
        # # file_path = '/Users/jayguo/Documents/waterchemistrydata_prior_to_2000_2019-12-03.csv'
        # file_path = upload_files_location + file
        # ckanUploadFile(resource_id, file_path)
