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
indices=$( cat $runfile | grep -w CHRNAMES | cut -d '=' -f2 | tr ':' ' ' )
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

if [ `expr ${#indices}` -lt 1 ]
then
   MSG="Invalid value for CHRNAMES in the runfile"
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
#else
	#rm -rf $outputdir/* #This would actually delete important data if the user did qc & trimming before running vriant calling (vc), so I'm commenting it! However, it might be needed to start fresh in the same folder if he is only doing vc. 
fi

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

truncate -s 0 $TopOutputLogs/pbs.ALIGN
truncate -s 0 $TopOutputLogs/pbs.summary_dependencies

generic_qsub_header=$TopOutputLogs/qsubGenericHeader
truncate -s 0 $generic_qsub_header
echo "#!/bin/bash" > $generic_qsub_header
echo "#PBS -q $queue" >> $generic_qsub_header
echo "#PBS -A $allocation" >> $generic_qsub_header
echo "#PBS -m ae" >> $generic_qsub_header
echo "#PBS -M $email" >> $generic_qsub_header
echo "#PBS -l walltime=${pbswalltime}" >> $generic_qsub_header

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
LOGS="Documentation about this run such as config files and results of QC tests will be placed in this folder:\n\n$outputdir/$deliverydir/docs/ \n\n"
echo -e "$MSG\n\nDetails:\n\n$LOGS" | mail -s "[Task #${reportticket}]" "$redmine,$email"
echo -e "$MSG\n\nDetails:\n\n$LOGS" >> $outputdir/$deliverydir/docs/Summary.Report

set +x
echo -e "\n\n########################################################################################" >&2
echo -e "########################################################################################" >&2
echo -e "########################################################################################" >&2
echo -e "#####                               MAIN LOOP STARTS HERE                      #########" >&2
echo -e "########################################################################################" >&2
echo -e "#####  Trimming has been performed already                                     #########" >&2
echo -e "#####  Alignment-dedup analysis: one qsub per sample                           #########" >&2
echo -e "#####  Realignment-recalibration-variantCalling: 25 qsubs per batch, one per chr    ####" >&2
echo -e "########################################################################################\n\n" >&2
set -x

`truncate -s 0 $TopOutputLogs/Anisimov.alignDedup.joblist`
`truncate -s 0 $TopOutputLogs/Anisimov.alignDedup.log`
`chmod ug=rw $TopOutputLogs/Anisimov.alignDedup.joblist`

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
	     ### Maybe not. We already run trimming and we want to keep those results
	     ### rm -R $outputdir/$sample
	     mkdir -p $outputdir/${sample}/align
	     mkdir -p $outputdir/${sample}/realign
	     mkdir -p $outputdir/${sample}/variant
	     mkdir -p $outputdir/$deliverydir/${sample}
	     mkdir -p $TopOutputLogs/${sample}
	else 
	     mkdir -p $outputdir/${sample}/align
	     mkdir -p $outputdir/${sample}/realign
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

	echo "nohup $scriptdir/align_dedup.sh $runfile ${sample} $FQ_R1 $FQ_R2 $TopOutputLogs/${sample}/log.alignDedup.${sample} $TopOutputLogs/${sample}/command.align_dedup.${sample} > $TopOutputLogs/${sample}/log.alignDedup.${sample}" > $TopOutputLogs/${sample}/command.align_dedup.${sample}
        `chmod ug=rw $TopOutputLogs/${sample}/command.align_dedup.${sample}`

        echo "$TopOutputLogs/${sample} command.align_dedup.${sample}" >> $TopOutputLogs/Anisimov.alignDedup.joblist
        (( inputsamplecounter++ )) # was not initiated above, so starts at zero
   fi # end non-empty line

done <  $sampleinfo	



set +x
echo -e "\n\n#######################################################################" >&2
echo -e "#####   Now create the Anisimov bundle for aligning all samples   #####" >&2
echo -e "#######################################################################\n\n" >&2
set -x

# calculate the number of nodes needed, to be numbers of samples +1
numalignnodes=$((inputsamplecounter+1))

#form qsub
alignqsub=$TopOutputLogs/qsub.alignDedup
cat $generic_qsub_header > $alignqsub

echo "#PBS -N alignDedup" >> $alignqsub
echo "#PBS -o $TopOutputLogs/log.alignDedup.ou" >> $alignqsub
echo "#PBS -e $TopOutputLogs/log.alignDedup.er" >> $alignqsub
echo "#PBS -l nodes=${numalignnodes}:ppn=$thr" >> $alignqsub
echo -e "\n" >> $alignqsub
echo "aprun -n $numalignnodes -N 1 -d $thr ~anisimov/scheduler/scheduler.x $TopOutputLogs/Anisimov.alignDedup.joblist /bin/bash > ${TopOutputLogs}/Anisimov.alignDedup.log" >> $alignqsub
echo -e "\n" >> $alignqsub
echo "cat ${outputdir}/logs/mail.alignDedup | mail -s \"[Task #${reportticket}]\" \"$redmine,$email\" " >> $alignqsub
`chmod ug=rw ${TopOutputLogs}/Anisimov.alignDedup.log`
`chmod ug=rw $alignqsub`               
alignjobid=`qsub $alignqsub` 
`qhold -h u $alignjobid`
echo $alignjobid >> $TopOutputLogs/pbs.ALIGN
echo $alignjobid >> $TopOutputLogs/pbs.summary_dependencies
echo `date`

if [ `expr ${#alignjobid}` -lt 1 ]
then
   MSG="unable to launch qsub align job for ${sample}. Exiting now"
   echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"  
   exit 1        
fi

`find $outputdir -type d | xargs chmod -R 770`
`find $outputdir -type f | xargs chmod -R 660`



if [ $analysis == "ALIGNMENT" -o $analysis == "ALIGN" -o $analysis == "ALIGN_ONLY" ]
then
   set +x; echo -e "\n ###### ANALYSIS = $analysis ends here. Wrapping up and quitting\n" >&2; set -x;
   # release all held jobs
   `qrls -h u $alignjobid`
else
   set +x
   echo -e "\n\n#######  this jobid=$alignjobid will be used to hold execution of realign_varcall.sh     ########\n\n" >&2
   set -x
   alnjobid=$( echo $alignjobid | cut -d '.' -f 1 )
   set +x
   echo -e "\n\n###############################################" >&2   
   echo -e "####   Now create   Realign-Vcall scripts  ####" >&2
   echo -e "###############################################\n\n" >&2
   set -x

       
   for chr in $indices
   do
      set +x
      echo -e "\n\n####################################" >&2 
      echo -e "####   CHROMOSOME    chr=$chr   " >&2
      echo -e "####################################\n\n" >&2
      set -x

      `truncate -s 0 $TopOutputLogs/Anisimov.realVcall.${chr}.joblist`
      `truncate -s 0 $TopOutputLogs/Anisimov.realVcall.${chr}.log`
      `truncate -s 0 $TopOutputLogs/pbs.REALVCALL.${chr}`

      inputsamplecounter=0;
      while read sampleLine
      do
         if [ `expr ${#sampleLine}` -lt 1 ]
         then
            echo "##############         skipping empty line      #####################" >&2
         else
            set +x
            echo -e "\n####   SAMPLE ${sample}   ####" >&2
            set -x
            echo "nohup $scriptdir/realign_varcall_by_chr.sh $runfile ${sample} $chr $TopOutputLogs/{sample}/log.realVcall.${sample}.$chr $TopOutputLogs/${sample}/command.realVcall.${sample}.$chr > $TopOutputLogs/${sample}/log.realVcall.${sample}.$chr" > $TopOutputLogs/${sample}/command.realVcall.${sample}.$chr
            `chmod ug=rw $TopOutputLogs/${sample}/command.realVcall.${sample}.$chr`
            echo "$TopOutputLogs/${sample} command.realVcall.${sample}.$chr" >> $TopOutputLogs/Anisimov.realVcall.${chr}.joblist

         fi # end non-empty line
      done <  $sampleinfo

      set +x
      echo -e "\n####" >&2
      echo -e "####  form Anisimov bundle for chromosome $chr; num nodes is same as for alignment  ####" >&2
      echo -e "####" >&2
      set -x
      realVcallqsub=$TopOutputLogs/qsub.realVcall.$chr
      cat $generic_qsub_header > $realVcallqsub
      echo "#PBS -N realVcall.$chr" >> $realVcallqsub
      echo "#PBS -o $TopOutputLogs/log.realVcall.$chr.ou" >> $realVcallqsub
      echo "#PBS -e $TopOutputLogs/log.realVcall.$chr.in" >> $realVcallqsub
      echo "#PBS -l nodes=${numalignnodes}:ppn=$thr" >> $realVcallqsub
      echo "#PBS -W depend=afterok:$alnjobid" >> $realVcallqsub
      echo -e "\n" >> $realVcallqsub
      echo "aprun -n $numalignnodes -N 1 -d $thr ~anisimov/scheduler/scheduler.x $TopOutputLogs/Anisimov.realVcall.${chr}.joblist /bin/bash > ${TopOutputLogs}/Anisimov.realVcall.$chr.log" >> $realVcallqsub
      echo -e "\n" >> $realVcallqsub
      echo "cat ${outputdir}/logs/mail.realVcall.$chr | mail -s \"[Task #${reportticket}]\" \"$redmine,$email\" " >> $realVcallqsub
      `chmod ug=rw ${TopOutputLogs}/Anisimov.realVcall.$chr.log`
      `chmod ug=rw $realVcallqsub`
      realVcalljobid=`qsub $realVcallqsub`
      `qhold -h u $alignjobid`
      echo $realVcalljobid >> $TopOutputLogs/pbs.REALVCALL.$chr
      echo $realVcalljobid >> $TopOutputLogs/pbs.summary_dependencies
      echo `date`

      if [ `expr ${#realVcalljobid}` -lt 1 ]
      then
         MSG="unable to launch qsub realVcall job for chromosome ${chr}. Exiting now"
         echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
         exit 1        
      fi
   done
fi
#           set +x  
#	   echo -e "\n\n########################################################################################" >&2            
#	   echo -e "####   Out of loop2. Now launching merge_vcf script for SAMPLE ${sample}       ##########" >&2
#	   echo -e "########################################################################################\n\n" >&2
#	   set -x 
#
#           vcalljobids=$( cat $TopOutputLogs/pbs.VCALL.${sample} | sed "s/\.[a-z]*//g" | tr "\n" ":" )
#
#	   echo -e "\n\n### this list of jobids=[$vcalljobids] will be used to hold execution of merge_vcf.sh #####\n\n"
#
#	   qsub1=$TopOutputLogs/qsub.merge.${sample}
#	   cat $generic_qsub_header > $qsub1
#	   echo "#PBS -N merge.${sample}" >> $qsub1
#	   echo "#PBS -o $TopOutputLogs/log.merge.${sample}.ou" >> $qsub1
#	   echo "#PBS -e $TopOutputLogs/log.merge.${sample}.in" >> $qsub1
#           echo "#PBS -W depend=afterok:$vcalljobids" >> $qsub1
#	   echo -e "\n" >> $qsub1
#################################################### azza: here should only be merge_bams of each sample
#	   echo "aprun -n $nodes -d $thr $scriptdir/merge_vcf.sh $runfile ${sample} $TopOutputLogs/log.mergeVcf.${sample}.in $TopOutputLogs/log.merge.${sample}.ou $TopOutputLogs/qsub.merge.${sample}" >> $qsub1
#	   `chmod ug=rw $qsub1`               
#	   mergejobid=`qsub $qsub1` 
#	   echo $mergejobid >> $TopOutputLogs/pbs.summary_dependencies
#	   echo `date`
#	
#           if [ `expr ${#mergejobid}` -lt 1 ]
#              then
#	        MSG="unable to launch qsub merge job for ${sample}. Exiting now"
#	        echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email" 
#	        exit 1        
#           fi
#azza: here should be calling variants using HC
#
#        fi # close the if statement checking whether the workflow end with alignment or not
        # release all held jobs
#        `qrls -h u $alignjobid`
#   fi  # end non-empty line
# OLD done <  $sampleinfo	

############################################################################################################################# azza's GenotypeGVCF
############################################################################################################################# azza's GenotypeGVCF
############################################################################################################################# azza's GenotypeGVCF
############################################################################################################################# azza's GenotypeGVCF
############################################################################################################################# azza's GenotypeGVCF
############################################################################################################################# azza's GenotypeGVCF
############################################################################################################################# azza's GenotypeGVCF

#	   set +x  
#           echo -e "\n\n########################################################################################" >&2
#           echo -e "####    Now launching joint_genotyping script for all SAMPLEs: each 200 together        ##########" >&2
#           echo -e "########################################################################################\n\n" >&2
#           set -x 
#
#           mergedjobsids=$( cat $TopOutputLogs/pbs.summary_dependencies | sed "s/\.[a-z]*//g" | tr "\n" ":" )
#
#           echo -e "\n\n### this list of jobids=[$mergedjobsids] will be used to hold execution of joint_vcfs.sh #####\n\n"
#
#           qsub1=$TopOutputLogs/qsub.jointcall
#           cat $generic_qsub_header > $qsub1
#           echo "#PBS -N JointCalling" >> $qsub1
#           echo "#PBS -o $TopOutputLogs/log.jointcall.ou" >> $qsub1
#           echo "#PBS -e $TopOutputLogs/log.jointcall.in" >> $qsub1
#           echo "#PBS -W depend=afterok:$mergedjobsids" >> $qsub1
#	   echo -e "\n" >> $qsub1
#           echo "aprun -n $nodes -d $thr $scriptdir/joint_vcf.sh $runfile $TopOutputLogs/log.jointcall.in $TopOutputLogs/log.jointcall.ou $TopOutputLogs/qsub.jointcall" >> $qsub1
#           `chmod ug=rw $qsub1`
#           jointcalljobid=`qsub $qsub1`
#           echo $jointcalljobid >> $TopOutputLogs/pbs.summary_dependencies
#           echo `date`
#
#           if [ `expr ${#jointcalljobid}` -lt 1 ]
#              then
#                MSG="unable to launch qsub jointVCFcall job for 200 samples. Exiting now"
#                echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
#                exit 1
#           fi

################################################################################################################################### end azza's block

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
echo "#PBS -l nodes=1:ppn=$thr" >> $summaryqsub
echo "#PBS -W depend=afterok:$alljobids " >> $summaryqsub
echo -e "\n" >> $summaryqsub
echo "aprun -n $nodes -d $thr $scriptdir/summary.sh $runfile $TopOutputLogs/log.summary.in $TopOutputLogs/log.summary.ou $TopOutputLogs/qsub.summary" >> $summaryqsub
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
