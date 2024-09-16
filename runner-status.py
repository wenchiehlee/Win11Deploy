TOTAL_FIRST_ID                = 2
TOTAL_LAST_ID                 = 4
THIS_FIRST_ID                 = 2  # Last START_ID is 2
THIS_LAST_ID                  = 2
#
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
        return 'online'
    elif runner['status'] == 'offline':
        return 'offline'
    else:
        return 'Unknown'

# Load secret .env file
load_dotenv()
# Store credentials
OWNER                   = os.getenv('OWNER')
REPO                    = os.getenv('REPO')
HEADER_TOKEN            = os.getenv('HEADER_TOKEN')
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

# [Index 1]: Update first column
wks.update_value('A1', 'Runner') 
wks.update_value('B1', 'OS') 
wks.update_value('C1', 'Status') 
wks.update_value('D1', 'Repo') 
wks.update_value('E1', 'Now-Last') 
wks.update_value('F1', 'Last update') 

# [Index TOTAL_FIRST_ID~THIS_FIRST_ID]:
for i in range(TOTAL_FIRST_ID, THIS_FIRST_ID ):
    data_A = wks.get_value('A'+str(i))
    print(str(i))

# Index THIS_FIRST_ID~
# GitHub API endpoint
url = f"https://api.github.com/repos/{OWNER}/{REPO}/actions/runners"

# HTTP headers
headers = {"Authorization": f"token {HEADER_TOKEN}"}

# Make the request
response = requests.get(url, headers=headers)

# Check if the request was successful
if response.status_code == 200:
    runners = response.json().get('runners', [])
    print("|ID |Runner name    |OS        |Repo                    |Status|")
    print("|---|---------------|----------|------------------------|------|")
    count=int(THIS_FIRST_ID)
    count_str=str(count)
    for runner in runners:  
        status=get_status(runner)
        print(f"|{count_str}  |{runner['name']}|{platform.system()} {platform.release()}|{OWNER}/{REPO} |{status}|")
        wks.update_value('A'+count_str, runner['name']) 
        wks.update_value('B'+count_str, platform.system()+platform.release())
        wks.update_value('C'+count_str, status) 
        wks.update_value('D'+count_str, f"{OWNER}/{REPO}") 
        wks.update_value('E'+count_str, f"=(NOW()-F"+count_str+")*1440") 
        wks.update_value('F'+count_str, str(now)) 
        count += 1
else:
    print(f"Failed to retrieve runners. Status code: {response.status_code}")

if (THIS_LAST_ID+1 != count):
    print("Error!!")
# [Index count~TOTAL_LAST_ID]:
for i in range(THIS_LAST_ID+1, TOTAL_LAST_ID+1 ):
    data_A = wks.get_value('A'+str(i))
    data_F = wks.get_value('F'+str(i))
    if (data_F):
        elapsed = (now - datetime.strptime(data_F,"%Y-%m-%d %H:%M:%S"))
        elapsed_minutes =  round(elapsed.total_seconds() / 60, 1)
        print(f"|{str(i)}  |{data_F}|{str(elapsed_minutes)}|")
        if (elapsed_minutes >= 10):
            wks.update_value('C'+str(i), "offline") 
