#!/bin/bash
set -x

####inputs

# 1 = folder that we are profiling
TargetFolder=$1

#2 = folder where output files will be placed
OutputFolder=$2

#3 = some basic name for output files that captures the nature of input folder we are profiling
Prefix=$3




##get file sizes and stripe information in an infinite loop

# clear output files
truncate -s 0 ${OutputFolder}/${Prefix}.FileSizeInfo
truncate -s 0 ${OutputFolder}/${Prefix}.GetStripeInfo

while true
do
   echo `date` >> ${OutputFolder}/${Prefix}.FileSizeInfo
   ls -R -l ${TargetFolder} >> ${OutputFolder}/${Prefix}.FileSizeInfo

   echo `date` >> ${OutputFolder}/${Prefix}.GetStripeInfo
   lfs getstripe --recursive ${TargetFolder} >> ${OutputFolder}/${Prefix}.GetStripeInfo

   # get this information every 2 minutes
   sleep 2m
done
