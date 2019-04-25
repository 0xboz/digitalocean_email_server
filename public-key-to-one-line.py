#!/usr/bin/env python
import sys
import os.path

arguments = sys.argv
filePath = arguments[1]
parentPath = os.path.split(filePath)[0]
fileName = os.path.split(filePath)[1]
newFileName = os.path.join(parentPath, 'opendkim-public-key.txt')

with open(fileName) as f:
    lines = f.readlines()
    newlines = []
    for line in lines[1:-1]:
        newlines.append(line.strip())

    public_key = ''.join(newlines)
    dkim_record = '"v=DKIM1; k=rsa; p={}"'.format(public_key)
    with open(newFileName, 'w') as f:
        f.write(public_key)
