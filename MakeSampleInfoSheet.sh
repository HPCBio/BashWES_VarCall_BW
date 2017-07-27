#!/bin/bash

SamplesFolder=$1
SampleInfoSheet=$2
truncate -s 0 ${SampleInfoSheet}

for file in ${SamplesFolder}/*_1.fastq.gz
do
   SampleName=`basename ${file} | cut -f 1 -d "_"`
   echo "${SampleName} ${SamplesFolder}/${SampleName}_1.fastq.gz ${SamplesFolder}/${SampleName}_2.fastq.gz" >> ${SampleInfoSheet}
done


