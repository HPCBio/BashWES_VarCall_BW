#!/usr/bin/python

'''
This program gathers the IDs from a given batch and generates a file that measures how the fastq
  files for each SRA grow

The table looks something like this:
(A question mark signifies that this file is not yet present in the fastq file directory.
 In the beginning, none of the files will be present so there should be question marks for all of
 the IDs at the beginning
)

Time(m)	SRA111	SRA222	SRA333
0	?	?	?
5	200	300	325
10	400	600	650

This information will be fed into gnuplot for visualization

First argument is the SRA ID list that was used to generate the batch files
Second argument is the name of the batch
Third argument is the time interval (in minutes) between size samples

'''

import re
import sys
import subprocess
import time

###
### GLOBAL VARIABLES
### 

sraListFile = sys.argv[1]
batchName = sys.argv[2]
interval = sys.argv[3]

# List of IDs to preserve order
sraIDs = []

###
### FUNCTION DEFINITIONS
###

def gatherInfo(time_string):
    # Gather all of the directory information
    proc = subprocess.Popen(['ls', '-l', '/projects/sciteam/baib/InputData_DoNotTouch/fastq_files'], 
                            stdout=subprocess.PIPE
			   )
    # List of lines returned from ls -l
    ls_info = proc.stdout.read().split('\n')
    line_items = [time_string]

    for ID in sraIDs:
        # After loop through all of the ls lines, this provides a way to see if the ID was found in any of them
        ID_found = True
        for ls_line in ls_info:
            size = re.search('(\S+\s){4}(\S+)(.+' + ID + ')', ls_line)
	    if (size != None):
                # Match found
                line_items.append(size.group(2))
                ID_found = True
                break
            else:
                ID_found = False
        if (not ID_found):
            line_items.append("?")

    # Return the line that will be added to the output file
    line = ""
    for i in line_items[:-1]:
        line += str(i) + "\t"
    line = line + line_items[-1] + "\n"
    return line

###
### IMPLEMENTATION
###

# Get the SRA IDs, and initialize the dictionary keys
with open(sraListFile) as F:
    for line in F:
        ID = line.strip()
        read1 = ID + "_1.fastq.gz"
        read2 = ID + "_2.fastq.gz"
	sraIDs.append(read1)
        sraIDs.append(read2)

# Create the output file
newFile = open('/projects/sciteam/baib/InputData_DoNotTouch/monitoringPlots/' + batchName + '_' + interval + ".txt", 'w')

# Write the header to the output file
newFile.write("time(m)\t")
for item in sraIDs[:len(sraIDs)]:
    newFile.write(item + "\t")

newFile.write(sraIDs[-1] + "\n")

newFile.close()

# Gather the info at constant intervals, killing the script when two consecutive entries have the same values
currentTime = 0.0

# Variables that hold the prev results
prev = None

while (True):

    # Open up the output file in append mode
    outFile = open('/projects/sciteam/baib/InputData_DoNotTouch/monitoringPlots/' + batchName + '_' + interval + ".txt", 'a')

    current = gatherInfo(currentTime)
    outFile.write(current)
    outFile.close()

    print("Sample taken at time " + str(currentTime) + " minutes")
 
    # Check if the sizes for the prev is the same as current
    if (prev is not None):
        p_sizes = re.search("(\S+\s)(.+)", prev).group(2)
        c_sizes = re.search("(\S+\s)(.+)", current).group(2)

        if (p_sizes == c_sizes):
            # End the program
            print("Monitoring program terminated because file sizes look like they are not changing")
	    break

    currentTime += float(interval)
    prev = current

    time.sleep(60 * currentTime)
