#!/bin/bash

mkdir -p /dev/shm/sra_files/sra

# Make a symlink from RAM to where the local sra database is stored
ln -sf /projects/sciteam/baib/InputData_DoNotTouch/localDB/refseq /dev/shm/sra_files/refseq

# Download the SRA file
~/.aspera/connect/bin/ascp -i ~/.aspera/connect/etc/asperaweb_id_dsa.openssh -k 1 -T -l800m anonftp@ftp.ncbi.nlm.nih.gov:/sra/sra-instant/reads/ByRun/sra/SRR/SRR347/SRR3477521/SRR3477521.sra /dev/shm/sra_files/sra

#Copy the sra file back to projects (but we will use the copy in RAM for processing
cp /dev/shm/sra_files/sra/SRR3477521.sra /projects/sciteam/baib/InputData_DoNotTouch/SRA_files/sra/SRR3477521.sra

# fastq-dump was configured to look in /dev/shm/sra_files using vdb-config in SRA toolkit bin folder
# Convert the SRA into fastq
/projects/sciteam/baib/builds/sra-toolkit/sra-tools-2.8.1-3/bin/fastq-dump -v --gzip --split-files -O /projects/sciteam/baib/InputData_DoNotTouch/fastq_files /dev/shm/sra_files/sra/SRR3477521.sra
