import click
# import json
import math
import os
import requests
from requests_toolbelt import MultipartEncoder, MultipartEncoderMonitor

from datetime import date #, timedelta
today = str(date.today())
# today = '2021-03-15'


####### CONFIGURE CKAN PARAMETERS #######
ckan_base = 'https://data.ca.gov'
ckan_api_key = os.environ.get('data_portal_key')
####### END OF CKAN PARAMTER CONFIGURATION #######


####### DAA - CONFIGURE UPLOAD FILES LOCATION AND LIST #######
upload_files_location = 'C:\\David\\_CA_data_portal\\CEDEN\\CEDEN_Datasets\\' + today + '\\'
# upload_files_location = 'C:\\Users\\daltare\\OneDrive - Water Boards\\projects\\CA_data_portal\\CEDEN\\1_data_download\\CEDEN_Datasets\\' + today + '/'

uploads = {
# sites
'All_CEDEN_Sites' + '_' + today + '.csv': 'a927cb45-0de1-47e8-96a5-a5290816797b',
# benthic
'BenthicData' + '_' + today + '.csv': '3dfee140-47d5-4e29-99ae-16b9b12a404f',
# toxicity
'ToxicityData' + '_' + today + '.csv': 'bd484e9b-426a-4ba6-ba4d-f5f8ce095836',
# chemistry
'WaterChemistryData_year-2021' + '_' + today + '.csv': 'dde19a95-504b-48d7-8f3e-8af3d484009f',
'WaterChemistryData_year-2020' + '_' + today + '.csv': '2eba14fa-2678-4d54-ad8b-f60784c1b234', 
'WaterChemistryData_year-2019' + '_' + today + '.csv': '6cf99106-f45f-4c17-80af-b91603f391d9',
'WaterChemistryData_year-2018' + '_' + today + '.csv': 'f638c764-89d5-4756-ac17-f6b20555d694',
'WaterChemistryData_year-2017' + '_' + today + '.csv': '68787549-8a78-4eea-b5b9-ef719e65a05c', 
'WaterChemistryData_year-2016' + '_' + today + '.csv': '42b906a2-9e30-4e44-92c9-0f94561e47fe', 
'WaterChemistryData_year-2015' + '_' + today + '.csv': '7d9384fa-70e1-4986-81d6-438ce5565be6',
'WaterChemistryData_year-2014' + '_' + today + '.csv': '7abfde16-61b6-425d-9c57-d6bd70700603', 
'WaterChemistryData_year-2013' + '_' + today + '.csv': '341627e6-a483-4e9e-9a85-9f73b6ddbbba',
'WaterChemistryData_year-2012' + '_' + today + '.csv': 'f9dd0348-85d5-4945-aa62-c7c9ad4cf6fd', 
'WaterChemistryData_year-2011' + '_' + today + '.csv': '4d01a693-2a22-466a-a60b-3d6f236326ff', 
'WaterChemistryData_year-2010' + '_' + today + '.csv': '572bf4d2-e83d-490a-9aa5-c1d574e36ae0',
'WaterChemistryData_year-2009' + '_' + today + '.csv': '5b136831-8870-46f2-8f72-fe79c23d7118',
'WaterChemistryData_year-2008' + '_' + today + '.csv': 'c587a47f-ac28-4f77-b85e-837939276a28',
'WaterChemistryData_year-2007' + '_' + today + '.csv': '13e64899-df32-461c-bec1-a4e72fcbbcfa',
'WaterChemistryData_year-2006' + '_' + today + '.csv': 'a31a7864-06b9-4a81-92ba-d8912834ca1d',
'WaterChemistryData_year-2005' + '_' + today + '.csv': '9538cbfa-f8be-4445-97dc-b931579bb927',
'WaterChemistryData_year-2004' + '_' + today + '.csv': 'c962f46d-6a7b-4618-90ec-3c8522836f28',
'WaterChemistryData_year-2003' + '_' + today + '.csv': 'd3f59df4-2a8d-4b40-b90f-8147e73335d9',
'WaterChemistryData_year-2002' + '_' + today + '.csv': '00c4ca34-064f-4526-8276-57533a1a36d9',
'WaterChemistryData_year-2001' + '_' + today + '.csv': 'cec6768c-99d3-45bf-9e56-d62561e9939e',
'WaterChemistryData_year-2000' + '_' + today + '.csv': '99402c9c-5175-47ca-8fce-cb6c5ecc8be6',
'WaterChemistryData_prior_to_2000' + '_' + today + '.csv': '158c8ca1-b02f-4665-99d6-2c1c15b6de5a', 
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
