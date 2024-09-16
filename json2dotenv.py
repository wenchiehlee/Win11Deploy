# python json2dotenv.py to get one line of json
import json
import base64
import os
from dotenv import load_dotenv, find_dotenv


with open('github-action-runner.json', 'r') as file:
    service_key = json.load(file)

# convert json to a string
service_key = json.dumps(service_key)

json_key = json.loads(service_key)
# encode service key
encoded_service_key = base64.b64encode(service_key.encode('utf-8'))

#print(service_key)
print(json_key)
# b'many_characters_here'