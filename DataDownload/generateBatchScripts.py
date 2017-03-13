#!/usr/bin/python

'''
Input:
    - file with list of SRA IDs
    - Name of the batch batch name

Output:
    - Within a directory with the provided batch name, this creates the subdirectories and
      shell scripts needed to allow the Anisimov Launcher to download the SRA files
        - The directory will always be placed within /projects/sciteam/baib/InputData_DoNotTouch/batches
          so the full path is not needed
    - Also creates the anisimov launcher job list file for this batch

Example:

    # sraList.txt
    SRR1
    SRR2
    SRR3

    # Command line script call
    python generateBatchScripts.py sraList.txt batch1

    # Resulting directories and files

    /projects/sciteam/baib/InputData_DoNotTouch/batches/batch1/SRR1/SRR1.sh
    /projects/sciteam/baib/InputData_DoNotTouch/batches/batch1/SRR2/SRR2.sh
    /projects/sciteam/baib/InputData_DoNotTouch/batches/batch1/SRR3/SRR3.sh
'''

import os
import os.path
import sys

###
### GLOBAL VARIABLES
###

sraListFile = sys.argv[1]
batchName = sys.argv[2]

batchFullPath = "/projects/sciteam/baib/InputData_DoNotTouch/batches/" + batchName

SRA_list = []

###
### FUNCTION DEFINITIONS
###

def createScripts(SRA_ID):
    subDirName = batchFullPath + "/" + SRA_ID

    # Create the subdirectory within the batch directory
    if (not os.path.isdir(subDirName)):
        os.mkdir(subDirName)
    
    # Create the shell script file
    shellFile = open(subDirName + "/" + SRA_ID + ".sh", "w")

    # Part of URL to sra file location that changes
    # Something like: "SRR/SRR347/SRR3477521/SRR3477521.sra "
    part = SRA_ID[:3] + "/" + SRA_ID[:6] + "/" + SRA_ID + "/" + SRA_ID + ".sra"

    # Write to the file
    shellFile.write("#!/bin/bash\n\n")

    shellFile.write("mkdir -p /dev/shm/sra_files/sra\n\n")
    shellFile.write("# Make a symlink from RAM to where the local sra database is stored\n")
    shellFile.write("ln -sf /projects/sciteam/baib/InputData_DoNotTouch/localDB/refseq /dev/shm/sra_files/refseq\n\n")

    shellFile.write("# Download the SRA file\n")
    shellFile.write("~/.aspera/connect/bin/ascp -i ~/.aspera/connect/etc/asperaweb_id_dsa.openssh -k 1 -T -l800m anonftp@ftp.ncbi.nlm.nih.gov:/sra/sra-instant/reads/ByRun/sra/" + part + " /dev/shm/sra_files/sra\n\n")

    shellFile.write("#Copy the sra file back to projects (but we will use the copy in RAM for processing\n")

    shellFile.write("cp /dev/shm/sra_files/sra/" + SRA_ID + ".sra /projects/sciteam/baib/InputData_DoNotTouch/SRA_files/sra/" + SRA_ID + ".sra\n\n")

    shellFile.write("# fastq-dump was configured to look in /dev/shm/sra_files using vdb-config in SRA toolkit bin folder\n")

    shellFile.write("# Convert the SRA into fastq\n")
    shellFile.write("/projects/sciteam/baib/builds/sra-toolkit/sra-tools-2.8.1-3/bin/fastq-dump -v --gzip --split-files -O /projects/sciteam/baib/InputData_DoNotTouch/fastq_files /dev/shm/sra_files/sra/" + SRA_ID + ".sra\n")

    shellFile.close()

def makeJobListFile():
    jobListFile = open("/projects/sciteam/baib/InputData_DoNotTouch/jobLists/" + batchName + "_JobList.txt", "w")
    for i in SRA_list:
        # Write the jobList for the Anisimov launcher
        # Something like "/projects/sciteam/baib/InputData_DoNotTouch/batches/batch1/SRR123 SRR123.sh"
        jobListFile.write(batchFullPath + "/" + i + " " + i + ".sh\n")
    jobListFile.close()

###
### IMPLEMENTATION
###

# Get the list of SRA IDs
with open(sraListFile) as F:
    for line in F:
	SRA_list.append(line.strip())

# If the batch directory does not exist, create it
if (not os.path.isdir(batchFullPath)):
    os.mkdir(batchFullPath)

# Create the subdirectories and shell scripts
for i in SRA_list:
    createScripts(i)

makeJobListFile()
