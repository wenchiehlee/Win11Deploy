# GitHub API endpoint 1
ENDPOINT1_ORG="ZhongZheng782"
GITHUB_API_ENDPOINT1 = f"https://api.github.com/orgs/{ENDPOINT1_ORG}/actions/runners"
ENDPOINT1_FIRST_ID                 = 2
ENDPOINT1_LAST_ID                  = 3
# GitHub API endpoint 2
ENDPOINT2_ORG="wenchiehlee"
ENDPOINT2_REPO="Win11Deploy"

GITHUB_API_ENDPOINT2 = f"https://api.github.com/repos/{ENDPOINT2_ORG}/{ENDPOINT2_REPO}/actions/runners"
ENDPOINT2_FIRST_ID                 = 4
ENDPOINT2_LAST_ID                  = 4
#
import requests
import pygsheets
import pandas as pd
import platform
import os
import sys
import tempfile
import json
from datetime import datetime
from dotenv import load_dotenv


def get_status(runner):
    if runner['status'] == 'online' and runner['busy'] == True:
        return 'busy'
    elif runner['status'] == 'online' and runner['busy'] == False:
        return 'idle'
    elif runner['status'] == 'offline':
        return 'offline'
    else:
        return 'Unknown'

# Load secret .env file
load_dotenv()
# Store credentials
ENDPOINT1_HEADER_TOKEN            = os.getenv('ENDPOINT1_HEADER_TOKEN')
ENDPOINT2_HEADER_TOKEN            = os.getenv('ENDPOINT2_HEADER_TOKEN')
GDRIVE_API_CREDENTIALS  = os.getenv('GDRIVE_API_CREDENTIALS')

# ------------------------------------------------------------------
## Authorize
# gc = pygsheets.authorize(service_file='./github-action-runner.json')

temp = tempfile.NamedTemporaryFile(delete=False)
temp.write(GDRIVE_API_CREDENTIALS.encode())
temp.flush()

gc = pygsheets.authorize(service_file=temp.name)

sht = gc.open_by_url( 'https://docs.google.com/spreadsheets/d/1LtxS_ZH3dd5ycHIlkHENfWahl7QCVwYgoXJstf6HzQY/edit?usp=sharing')

temp.close()
os.unlink(temp.name)


now=datetime.now()

# read whole worksheet
wks_list = sht.worksheets()
# specify worksheet
wks = sht.worksheet_by_title('Runners') 

data_E = float(wks.get_value('E2'))
if (  data_E < 15):
    print(f"Already updated by others in {data_E}m! Quit!")
    quit()

# [Index 1]: Update first column
#wks.update_value('A1', 'Runner') 
#wks.update_value('B1', 'OS') 
#wks.update_value('C1', 'Status') 
#wks.update_value('D1', 'Repo') 
#wks.update_value('E1', 'Now-Last') 
#wks.update_value('F1', 'Last update') 

print("|ID |Runner name    |OS        |Repo                    |Status |")
print("|---|---------------|----------|------------------------|-------|")

# Index ENDPOINT1_FIRST_ID~ENDPOINT1_LAST_ID

# HTTP headers
headers = {"Authorization": f"token {ENDPOINT1_HEADER_TOKEN}"}

# Make the request
response = requests.get(GITHUB_API_ENDPOINT1, headers=headers)

# Check if the request was successful
count=int(ENDPOINT1_FIRST_ID)
if response.status_code == 200:
    #print(f"{response.json()}")
    runners = response.json().get('runners', [])

    for runner in runners:  
        count_str=str(count)
        status=get_status(runner)
        print(f"|{count_str}  |{runner['name']}|{runner['os']}| {ENDPOINT1_ORG} |{status}|")
        wks.update_value('A'+count_str, runner['name']) 
        wks.update_value('B'+count_str, runner['os'])
        wks.update_value('C'+count_str, status) 
        wks.update_value('D'+count_str, f"{ENDPOINT1_ORG}") 
        wks.update_value('E'+count_str, f"=(NOW()-F"+count_str+")*1440") 
        wks.update_value('F'+count_str, str(now)) 
        count += 1
    if (ENDPOINT1_LAST_ID+1 != count):
        print("Error!!")
else:
    print(f"Failed to retrieve runners. Status code: {response.status_code}")


# Index ENDPOINT2_FIRST_ID~ENDPOINT2_LAST_ID

# HTTP headers
headers = {"Authorization": f"token {ENDPOINT2_HEADER_TOKEN}"}

# Make the request
response = requests.get(GITHUB_API_ENDPOINT2, headers=headers)

# Check if the request was successful
count=int(ENDPOINT2_FIRST_ID)
if response.status_code == 200:
    #print(f"{response.json()}")
    runners = response.json().get('runners', [])

    count_str=str(count)
    for runner in runners:  
        status=get_status(runner)
        print(f"|{count_str}  |{runner['name']}|{runner['os']}| {ENDPOINT2_ORG}/{ENDPOINT2_REPO}|{status}|")
        wks.update_value('A'+count_str, runner['name']) 
        wks.update_value('B'+count_str, runner['os'])
        wks.update_value('C'+count_str, status) 
        wks.update_value('D'+count_str, f"{ENDPOINT2_ORG}/{ENDPOINT2_REPO}") 
        wks.update_value('E'+count_str, f"=(NOW()-F"+count_str+")*1440") 
        wks.update_value('F'+count_str, str(now)) 
        count += 1
    if (ENDPOINT2_LAST_ID+1 != count):
        print("Error!!")
else:
    print(f"Failed to retrieve runners. Status code: {response.status_code}")