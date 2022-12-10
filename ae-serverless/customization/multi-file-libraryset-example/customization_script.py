import cos_utils
import os
import sys

def customize(install_path, params):
  for param in params:
   print(param)
  endpoint = params[0]
  bucket_name = params[1]
  access_key = params[2]
  secret_key = params[3]
  directory = params[4]
  files = params[5]
  cos = cos_utils.get_cos_object(access_key, secret_key, endpoint)
  
  i=0
  while i<len(files):
    retCode = cos_utils.download_file("{}/{}".format(directory, files[i]), cos, bucket_name, "{}/{}".format(install_path, files[i]))
    if (retCode != 0):
       print("non-zero return code while downloading file    {}".format(str(retCode)))
       sys.exit(retCode)
    else:
       print("Successfully downloaded file...")
    i=i+1
