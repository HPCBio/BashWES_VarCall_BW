#!/bin/bash

# Download the SRA file
~/.aspera/connect/bin/ascp -i ~/.aspera/connect/etc/asperaweb_id_dsa.openssh -k 1 -T -l800m anonftp@ftp.ncbi.nlm.nih.gov:/sra/sra-instant/reads/ByRun/sra/SRR/SRR347/SRR3477521/SRR3477521.sra /dev/shm/sra_files/sra

# fastq-dump was configured to look in /dev/shm/sra_files using vdb-config in SRA toolkit bin folder
# Convert the SRA into fastq
/projects/sciteam/baib/builds/sra-toolkit/sra-tools-2.8.1-3/bin/fastq-dump -v --gzip --split-files -O /projects/sciteam/baib/InputData_DoNotTouch/fastq_files /dev/shm/sra_files/sra/SRR3477521.sra

