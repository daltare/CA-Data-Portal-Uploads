# ckan-chunked-file-upload

This is a repository containing the an example script that allows a user to perform a chunked file upload to a CKAN resource.


## Getting Started

### Prerequisites

To run this script, you will need a working version of Python and install the required Python modules.



### Installing

Install the required Python modules by running the following command:

```
pip install -r requirements.txt
```



## Configuring the Script

To run this script, you will need to edit several variables in the main.py file
```
ckan_base: Url of the CKAN site without the trailing slash
ckan_api_key: User API key from CKAN
resource_id: ID of an existing CKAN resource to update
file_path: File path of file to upload to CKAN
```



## Running the Script

After the main.py file has been configured correctly, you can run this script via the command line by running:
```
python main.py
```
