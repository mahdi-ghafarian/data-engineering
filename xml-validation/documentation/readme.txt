1. Python Version: 3.14.6 

2. embedded python is used inside the project folder because of python installation restriction in the organization.
https://www.python.org/ftp/python/3.14.6/python-3.14.6-embed-amd64.zip

unzip the file and rename it to python

3. download get-pip.py from the following link and copy to resources:
https://bootstrap.pypa.io/get-pip.py

4. in python folder look for python314._pth
uncomment the "import site" line

3. requirements.txt is created by following command in venv created by VSCode:
# pip freeze > requirements.txt

3.Dependencies:
# pip install lxml



