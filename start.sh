#!/bin/bash

################################################################################################ 
# Program to calculate raw variants from human samples of WES short reads
# In order to run this pipeline please type at the command line
# /FULL/PATH/start.sh /FULL/PATH/<runfile>
################################################################################################


set -x
redmine=hpcbio-redmine@igb.illinois.edu

if [ $# != 1 ]
then
        MSG="Parameter mismatch.\nRerun like this: /FULL/PATH/$0 /FULL/PATH/<runfile>\n"
        echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s "Variant Calling Workflow failure message" "$redmine"
        exit 1;
fi

set +x
echo -e "\n\n########################################################################################" >&2
echo -e     "#############                BEGIN VARIANT CALLING WORKFLOW              ###############">&2
echo -e     "########################################################################################\n\n">&2
set -x


echo `date`	
scriptfile=$0
runfile=$1
if [ !  -s $runfile ]
then
   MSG="program=$0 stopped at line=$LINENO. $runfile runfile not found."
   exit 1;
fi
batchname=`basename $runfile .runfile`

set +x
echo -e "\n\n########################################################################################" >&2
echo -e "#############                CHECKING PARAMETERS                         ###############" >&2
echo -e "########################################################################################\n\n" >&2
set -x

reportticket=$( cat $runfile | grep -w REPORTTICKET | cut -d '=' -f2 )
outputdir=$( cat $runfile | grep -w OUTPUTDIR | cut -d '=' -f2 )
tmpdir=$( cat $runfile | grep -w TMPDIR | cut -d '=' -f2 )
deliverydir=$( cat $runfile | grep -w DELIVERYFOLDER | cut -d '=' -f2 )  
scriptdir=$( cat $runfile | grep -w SCRIPTDIR | cut -d '=' -f2 )
email=$( cat $runfile | grep -w EMAIL | cut -d '=' -f2 )
sampleinfo=$( cat $runfile | grep -w SAMPLEINFORMATION | cut -d '=' -f2 )
numsamples=$(wc -l $sampleinfo)
refdir=$( cat $runfile | grep -w REFGENOMEDIR | cut -d '=' -f2 )
refgenome=$( cat $runfile | grep -w REFGENOME | cut -d '=' -f2 )        
dbSNP=$( cat $runfile | grep -w DBSNP | cut -d '=' -f2 )
sPL=$( cat $runfile | grep -w SAMPLEPL | cut -d '=' -f2 )
sCN=$( cat $runfile | grep -w SAMPLECN | cut -d '=' -f2 )
sLB=$( cat $runfile | grep -w SAMPLELB | cut -d '=' -f2 )
dup_cutoff=$( cat $runfile | grep -w  DUP_CUTOFF | cut -d '=' -f2 )
map_cutoff=$( cat $runfile | grep -w  MAP_CUTOFF | cut -d '=' -f2 )
analysis=$( cat $runfile | grep -w ANALYSIS | cut -d '=' -f2 | tr '[a-z]' '[A-Z]' )
alignertool=$( cat $runfile | grep -w ALIGNERTOOL | cut -d '=' -f2 | tr '[a-z]' '[A-Z]' )
markduplicates=$( cat $runfile | grep -w MARKDUPLICATESTOOL | cut -d '=' -f2 | tr '[a-z]' '[A-Z]' )
samblasterdir=$( cat $runfile | grep -w SAMBLASTERDIR | cut -d '=' -f2 )
picardir=$( cat $runfile | grep -w PICARDIR | cut -d '=' -f2 )
gatkdir=$( cat $runfile | grep -w GATKDIR | cut -d '=' -f2 )
samtoolsdir=$( cat $runfile | grep -w SAMDIR | cut -d '=' -f2 )
bwamemdir=$( cat $runfile | grep -w BWAMEMDIR | cut -d '=' -f2 )
javadir=$( cat $runfile | grep -w JAVADIR | cut -d '=' -f2 )
novocraftdir=$( cat $runfile | grep -w NOVOCRAFTDIR | cut -d '=' -f2 )
fastqcdir=$( cat $runfile | grep -w FASTQCDIR | cut -d '=' -f2 )
thr=$( cat $runfile | grep -w PBSCORES | cut -d '=' -f2 )
nodes=$( cat $runfile | grep -w PBSNODES | cut -d '=' -f2 )
queue=$( cat $runfile | grep -w PBSQUEUE | cut -d '=' -f2 )
allocation=$( cat $runfile | grep -w ALLOCATION | cut -d '=' -f2 )
pbswalltime=$( cat $runfile | grep -w PBSWALLTIME | cut -d '=' -f2 )

if [ `expr ${#tmpdir}` -lt 1  ]
then
	MSG="Invalid value specified for TMPDIR in the runfile."
	echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
	exit 1;
fi

if [ ! -d  $refdir  ]
then
	MSG="Invalid value specified for REFGENOMEDIR=$refdir in the runfile."
	echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
	exit 1;
fi

if [ ! -s  $refdir/$refgenome  ]
then
	MSG="Invalid value specified for REFGENOME=$refgenome in the runfile."
	echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
	exit 1;
fi

if [ ! -s  $refdir/$dbSNP  ]
then
	MSG="Invalid value specified for DBSNP=$dbSNP in the runfile."
	echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
	exit 1;
fi

if [[ -z "${alignertool// }" ]]
then
   MSG="Value for ALIGNERTOOL=$alignertool in the runfile is empty. Please edit the runfile to specify the aligner name."
   echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
   exit 1;
else
   if [ ${alignertool} != "BWAMEM"  -a $alignertool != "BWA_MEM" -a $alignertool != "NOVOALIGN" ]
   then
      MSG="Incorrect value for ALIGNERTOOL=$aligner_tool in the runfile."
      echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
      exit 1;
   fi
fi

if [ -z $email ]
then
   MSG="Invalid value for parameter PBSEMAIL=$email in the runfile"
   echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
   exit 1;
fi

if [ `expr ${#sLB}` -lt 1 -o `expr ${#sPL}` -lt 1 -o `expr ${#sCN}` -lt 1 ] 
then
	MSG="SAMPLELB=$sLB SAMPLEPL=$sPL SAMPLECN=$sCN at least one of these fields has invalid values. "
	echo -e "program=$0 stopped at line=$LINENO.\nReason=$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
	exit 1;
fi

if [ `expr ${#dup_cutoff}` -lt 1 -o `expr ${#map_cutoff}` -lt 1 ]
then
   MSG="Invalid value for MAP_CUTOFF=$map_cutoff or for DUP_CUTOFF=$dup_cutoff  in the runfile"
   echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
   exit 1;
fi



if [ $markduplicates != "NOVOSORT" -a $markduplicates != "SAMBLASTER" -a $markduplicates != "PICARD" ]
then
    MSG="Invalid value for parameter MARKDUPLICATESTOOL=$markduplicates  in the runfile."
    echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
    exit 1;
fi

if [ ! -s $sampleinfo ]
then
    MSG="SAMPLEINFORMATION=$sampleinfo  file not found."
    echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
    exit 1;
fi

if [ $numsamples -lt 1 ]
then
    MSG="SAMPLEINFORMATION=$sampleinfo  file is empty."
    echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
    exit 1;	
fi

set +x 
echo -e "\n\n########################################################################################" >&2
echo -e "###########                      checking PBS params                      ##############" >&2
echo -e "########################################################################################\n\n" >&2
set -x

if [ `expr ${#thr}` -lt 1 ]
then
    thr=$PBS_NUM_PPN
fi

if [ `expr ${#nodes}` -lt 1 ]
then
    nodes=1
fi

if [ `expr ${#queue}` -lt 1 ]
then
    queue="default"
fi

set +x 
echo -e "\n\n########################################################################################" >&2
echo -e "###########                      checking tools                       ##################" >&2
echo -e "########################################################################################\n\n" >&2
set -x

########################## Insert commands to check the full paths of tools :)

hash $samblasterdir/samblaster 2>/dev/null || { echo >&2 "I require samblaster but it's not installed.  Aborting."; exit 1; }


if [ ! -d  $picardir  ]
then
        MSG="Invalid value specified for PICARDIR=$picardir in the runfile."
        echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
        exit 1;
fi

if [ ! -d  $gatkdir  ]
then
        MSG="Invalid value specified for GATKDIR=$gatkdir in the runfile."
        echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
        exit 1;
fi

hash  $samtoolsdir/samtools 2>/dev/null || { echo >&2 "I require sambtools but it's not installed.  Aborting."; exit 1; }

if [ ! -d  $bwamemdir  ]
then
        MSG="Invalid value specified for BWAMEMDIR=$bwamemdir in the runfile."
        echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
        exit 1;
fi

if [ ! -d  $javadir  ]
then
        MSG="Invalid value specified for JAVADIR=$javadir in the runfile."
        echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
        exit 1;
fi

if [ ! -d  $novocraftdir  ]
then
        MSG="Invalid value specified for NOVOCRAFTDIR=$novocraftdir in the runfile."
        echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
        exit 1;
fi

if [ ! -d  $fastqcdir  ]
then
        MSG="Invalid value specified for FASTQDIR=$fastqcdir in the runfile."
        echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
        exit 1;
fi







set +x
echo -e "\n\n########################################################################################" >&2
echo -e "###########  Everything seems ok. Now setup/configure output folders and files   #######" >&2
echo -e "########################################################################################\n\n" >&2
set -x

if [ ! -d $outputdir ]; then
	mkdir $outputdir
else
    rm -rf $outputdir/* 
    #This would actually delete important data if the user did qc & trimming before running vriant calling (vc), 
    # so it was commented out; but for ADSP on BW project looks like we are not doing QC or trimming, so leaving it in for reruns
fi
# setting the striping on output folder to ease the i/o bottlenecks during alignment
# decided not to do b/c files are small and lots of them/lots of samples in ADSP projects
#lfs setstripe -c 3 $outputdir

#setfacl -Rm   g::rwx $outputdir  #gives the group rwx permission, and to subdirectories
#setfacl -Rm d:g::rwx $outputdir  #passes the permissions to newly created files/folders

if [ ! -d $outputdir/logs  ]
then
        # the output directory does not exist. create it
        mkdir -p $outputdir/logs
fi

if [ ! -d $outputdir/$deliverydir/docs  ]
then
        # the delivery directory does not exist. create it
	mkdir -p $outputdir/$deliverydir/docs
fi

if [ ! -d $outputdir/$deliverydir/jointVCFs  ]
then
        # the jointVCF directory (containing files before VQSR) does not exist. create it
        mkdir -p $outputdir/$deliverydir/jointVCFs
fi
`chmod -R ug=rwx $outputdir`


`cp $runfile    $outputdir/$deliverydir/docs/runfile.txt`
`cp $sampleinfo $outputdir/$deliverydir/docs/sampleinfo.txt`
truncate -s 0   $outputdir/$deliverydir/docs/Summary.Report
truncate -s 0   $outputdir/$deliverydir/docs/QC_test_results.txt 

runfile=$outputdir/$deliverydir/docs/runfile.txt
TopOutputLogs=$outputdir/logs

truncate -s 0 $TopOutputLogs/pbs.$analysis
truncate -s 0 $TopOutputLogs/pbs.summary_dependencies
truncate -s 0 $TopOutputLogs/mail.${analysis}.SUCCESS
truncate -s 0 $TopOutputLogs/mail.${analysis}.FAILURE

generic_qsub_header=$TopOutputLogs/qsubGenericHeader
truncate -s 0 $generic_qsub_header
echo "#!/bin/bash" > $generic_qsub_header
echo "#PBS -q $queue" >> $generic_qsub_header
echo "#PBS -A $allocation" >> $generic_qsub_header
echo "#PBS -m ae" >> $generic_qsub_header
echo "#PBS -M $email" >> $generic_qsub_header
echo "#PBS -l walltime=${pbswalltime}" >> $generic_qsub_header
echo "#PBS -l flags=commtransparent" >> $generic_qsub_header

set +x
echo -e "##### let's check that it worked and that the file was created                     ####" >&2
set -x

if [ ! -s $generic_qsub_header ]
then 
    MSG="$generic_qsub_header is empty"
    echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
    exit 1;
fi
`find $outputdir -type d | xargs chmod -R 770`
`find $outputdir -type f | xargs chmod -R 660`

set +x
echo -e "\n\n########################################################################################" >&2
echo -e "################### Documenting progress on redmine with this message ##################" >&2
echo -e "########################################################################################" >&2
echo -e "##### the first part of the Report also needs to be stored in Summary.Report      ######" >&2
echo -e "########################################################################################\n\n" >&2
set -x


MSG="Variant calling workflow  started by username:$USER at: "$( echo `date` )
LOGS="Documentation about this run such as config files and results of QC tests will be placed in this folder:\n$outputdir/$deliverydir/docs/ \n\n"
echo -e "$MSG\n\nDetails:\n\n$LOGS" | mail -s "[Task #${reportticket}]" "$redmine,$email"
echo -e "$MSG\n\nDetails:\n\n$LOGS" >> $outputdir/$deliverydir/docs/Summary.Report







set +x
echo -e "\n\n########################################################################################" >&2
echo -e "########################################################################################" >&2
echo -e "#####                               MAIN LOOP STARTS HERE                      #########" >&2
echo -e "########################################################################################" >&2
echo -e "########################################################################################\n\n" >&2
set -x

`truncate -s 0 $TopOutputLogs/Anisimov.${analysis}.joblist`
`truncate -s 0 $TopOutputLogs/Anisimov.${analysis}.log`
`chmod ug=rw $TopOutputLogs/Anisimov.${analysis}.*`

while read sampleLine
do
    if [ `expr ${#sampleLine}` -lt 1 ]
    then
	set +x 
	echo -e "\n\n########################################################################################" >&2
	echo -e "##############                 skipping empty line        ##############################" >&2
	echo -e "########################################################################################\n\n" >&2
    else
	echo -e "\n\n########################################################################################" >&2
	echo -e "#####         Processing next line $sampleLine                                ##########" >&2
	echo -e "##### col1=sample_name col2=read1 col3=read2  including full paths            ##########" >&2
	echo -e "##### sample_name will be used for directory namas and in RG line of BAM files##########" >&2
	echo -e "########################################################################################\n\n" >&2
	set -x

	sample=$( echo "$sampleLine" | cut -d ' ' -f 1 ) 
	FQ_R1=$( echo "$sampleLine" | cut -d ' '  -f 2 )
	FQ_R2=$( echo "$sampleLine" | cut -d ' ' -f 3 )

	if [ `expr ${#sample}` -lt 1 ]
	then
	     MSG="unable to parse line $sampleLine"
	     echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"                     
	     exit 1
	fi

	if [ `expr ${#FQ_R1}` -lt 1 ]
	then
	     MSG="unable to parse line $sampleLine"
	     echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"                     
	     exit 1
	elif [ ! -s $FQ_R1 ]
	then
	     MSG="$FQ_R1 read1 file not found"
	     echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"                                          
	     exit 1                
	fi

	if [ `expr ${#FQ_R2}` -lt 1 ]
	then
	     MSG="unable to parse line $sampleLine"
	     echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"                     
	     exit 1
	elif [ ! -s $FQ_R2 ]
	then
	     MSG="$FQ_R2 read2 file not found"
	     echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"                     
	     exit 1                
	fi
	
	set +x
	echo -e "\n\n########################################################################################" >&2
	echo -e "###   Everything seems in order. Now creating folders where results will go  ###########" >&2
	echo -e "########################################################################################\n\n" >&2
	set -x

	if [ -d $outputdir/${sample} ]
	then
	     ### $outputdir/$sample already exists. Resetting it now. 
	     ### rm -R $outputdir/$sample
	     mkdir -p $outputdir/${sample}/align
	     mkdir -p $outputdir/${sample}/realrecal
	     mkdir -p $outputdir/${sample}/variant
	     mkdir -p $outputdir/$deliverydir/${sample}
	     mkdir -p $TopOutputLogs/${sample}
	else 
	     mkdir -p $outputdir/${sample}/align
	     mkdir -p $outputdir/${sample}/realrecal
	     mkdir -p $outputdir/${sample}/variant
	     mkdir -p $outputdir/$deliverydir/${sample}	     
	     mkdir -p $TopOutputLogs/${sample}
	fi
        `find $outputdir/${sample} -type d | xargs chmod -R 770`
        `find $outputdir/${sample} -type f | xargs chmod -R 660`

	
	set +x
	echo -e "\n\n########################################################################################" >&2  
	echo -e "####   Creating alignment script for   " >&2
	echo -e "####   SAMPLE ${sample}   " >&2
	echo -e "####   with R1=$FQ_R1     " >&2
	echo -e "####   and  R2=$FQ_R2     " >&2
	echo -e "########################################################################################\n\n" >&2
	set -x

        if [ $analysis == "ALIGNMENT" -o $analysis == "ALIGN" -o $analysis == "ALIGN_ONLY" ]
        then
           echo "nohup $scriptdir/align_dedup.sh $runfile ${sample} $FQ_R1 $FQ_R2 $TopOutputLogs/${sample}/log.alignDedup.${sample} $TopOutputLogs/${sample}/command.$analysis.${sample} > $TopOutputLogs/${sample}/log.alignDedup.${sample}" > $TopOutputLogs/${sample}/command.$analysis.${sample}
        else
           echo "nohup $scriptdir/align_dedup.sh $runfile ${sample} $FQ_R1 $FQ_R2 $TopOutputLogs/${sample}/log.alignDedup.${sample} $TopOutputLogs/${sample}/command.$analysis.${sample} > $TopOutputLogs/${sample}/log.alignDedup.${sample}" > $TopOutputLogs/${sample}/command.$analysis.${sample}
           echo -e "\n" >> $TopOutputLogs/${sample}/command.$analysis.${sample}
           echo "nohup $scriptdir/real_recal_varcall_WES.sh $runfile ${sample} $TopOutputLogs/${sample}/log.recalVcall.${sample} $TopOutputLogs/${sample}/command.$analysis.${sample} > $TopOutputLogs/${sample}/log.recalVcall.${sample}" >> $TopOutputLogs/${sample}/command.$analysis.${sample}
        fi

        `chmod ug=rw $TopOutputLogs/${sample}/command.$analysis.${sample}`
        echo "$TopOutputLogs/${sample} command.$analysis.${sample}" >> $TopOutputLogs/Anisimov.${analysis}.joblist
        (( inputsamplecounter++ )) # was not initiated above, so starts at zero
   fi # end non-empty line

done <  $sampleinfo	



set +x
echo -e "\n\n#######################################################################" >&2
echo -e "#####   Now create the Anisimov bundle for analyzing all samples   #####" >&2
echo -e "#######################################################################\n\n" >&2
set -x

# calculate the number of nodes needed, to be numbers of samples divided by 2 + 1
# divide by 2 because we will put two samples per node
# and +1 for launcher or an odd sample
numnodes=$((inputsamplecounter/2+1))
# if batch has large files, then use one sample per node
#numnodes=$((inputsamplecounter+1))

# number of processing elements for aprun = num samples + 1 for launcher
numPE=$((inputsamplecounter+1))

#form qsub
analysisqsub=$TopOutputLogs/qsub.${analysis}
cat $generic_qsub_header > $analysisqsub

echo "#PBS -N ${batchname}.${analysis}" >> $analysisqsub
echo "#PBS -o $TopOutputLogs/log.${analysis}.ou" >> $analysisqsub
echo "#PBS -e $TopOutputLogs/log.${analysis}.er" >> $analysisqsub
echo "#PBS -l nodes=${numnodes}:ppn=32" >> $analysisqsub
echo -e "\n" >> $analysisqsub
echo "$scriptdir/MonitorFileGrowth.sh ${outputdir} $TopOutputLogs ${batchname} &"  >> $analysisqsub
echo "monitorPID=\$!" >> $analysisqsub 
echo -e "\n" >> $analysisqsub
echo "aprun -n $numPE -N 2 -d $thr ~anisimov/scheduler/scheduler.x $TopOutputLogs/Anisimov.${analysis}.joblist /bin/bash -noexit > ${TopOutputLogs}/Anisimov.${analysis}.log" >> $analysisqsub
echo "kill -9 \${monitorPID}" >> $analysisqsub
echo -e "\n" >> $analysisqsub
echo "cat ${outputdir}/logs/mail.${analysis}.SUCCESS | mail -s \"[Task #${reportticket}]\" \"$redmine,$email\" " >> $analysisqsub
echo "cat ${outputdir}/logs/mail.${analysis}.FAILURE | mail -s \"[Task #${reportticket}]\" \"$redmine,$email\" " >> $analysisqsub
echo -e "\n" >> $analysisqsub
echo "cp ${outputdir}/logs/mail.${analysis}.SUCCESS $outputdir/$deliverydir/docs" >> $analysisqsub
echo "cp ${outputdir}/logs/mail.${analysis}.FAILURE $outputdir/$deliverydir/docs" >> $analysisqsub
echo "cp ${TopOutputLogs}/Anisimov.${analysis}.log $outputdir/$deliverydir/docs" >> $analysisqsub

`chmod ug=rw ${TopOutputLogs}/Anisimov.${analysis}.log`
`chmod ug=rw $analysisqsub`
analysisjobid=`qsub $analysisqsub` 
`qhold -h u ${analysisjobid}`
echo $analysisjobid >> $TopOutputLogs/pbs.${analysis}
echo $analysisjobid >> $TopOutputLogs/pbs.summary_dependencies
echo `date`

if [ `expr ${#analysisjobid}` -lt 1 ]
then
   MSG="unable to launch ${analysis} qsub job $analysisjobid. Exiting now"
   echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"  
   exit 1        
fi

`find $outputdir -type d | xargs chmod -R 770`
`find $outputdir -type f | xargs chmod -R 660`



       
set +x
echo -e "\n\n########################################################################################" >&2
echo -e "########################################################################################" >&2
echo -e "#################           MAIN LOOP ENDS HERE                  #######################" >&2
echo -e "########################################################################################" >&2
echo -e "########################################################################################" >&2
echo -e "#################     Now, we need to generate summary           #######################" >&2
echo -e "########################################################################################" >&2
echo -e "########################################################################################\n\n" >&2
set -x

alljobids=$( cat $TopOutputLogs/pbs.summary_dependencies | sed "s/\.[a-z]*//g" | tr "\n" ":" )

set +x
echo -e "\n\n### this list of jobids=[$alljobids] will be used to hold execution of summary.sh #####\n\n" >&2
set -x

summaryqsub=$TopOutputLogs/qsub.summary
cat $generic_qsub_header > $summaryqsub
echo "#PBS -N Summary_vcall" >> $summaryqsub
echo "#PBS -o $TopOutputLogs/log.summary.ou" >> $summaryqsub
echo "#PBS -e $TopOutputLogs/log.summary.in" >> $summaryqsub
echo "#PBS -l nodes=1:ppn=32" >> $summaryqsub
echo "#PBS -W depend=afterok:$alljobids " >> $summaryqsub
echo -e "\n" >> $summaryqsub
echo "aprun -n $nodes -d $thr $scriptdir/summary.sh $runfile $TopOutputLogs/log.summary.in $TopOutputLogs/log.summary.ou $TopOutputLogs/qsub.summary" >> $summaryqsub
echo -e "\n" >> $summaryqsub
echo "cat $outputdir/$deliverydir/docs/Summary.Report | mail -s \"[Task #${reportticket}]\" \"$redmine,$email\" " >> $summaryqsub
`chmod ug=rw $summaryqsub`
lastjobid=`qsub $summaryqsub`
echo $lastjobid >> $TopOutputLogs/pbs.SUMMARY
echo `date`     


`find $outputdir -type d | xargs chmod -R 770`
`find $outputdir -type f | xargs chmod -R 660`


if [ `expr ${#lastjobid}` -lt 1 ]
then
     MSG="unable to launch qsub summary job. Exiting now"
     echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"                     
     exit 1        
fi

# release all held jobs
releasejobids=$( cat $TopOutputLogs/pbs.summary_dependencies | sed "s/\.[a-z]*//g" | tr "\n" " " )
`qrls -h u $releasejobids`

set +x        
echo -e "\n\n########################################################################################" >&2
echo -e "##############                 EXITING NOW                            ##################" >&2	
echo -e "########################################################################################\n\n" >&2
set -x
