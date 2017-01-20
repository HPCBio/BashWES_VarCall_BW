#!/bin/bash

################################################################################################ 
# Program to filter variants with VQSR. Datasets of raw variants come from human samples of WES short reads
# In order to run this pipeline please type at the command line
# path/to/scriptdir/start_vqsr.sh <runfile>
################################################################################################
##redmine=hpcbio-redmine@igb.illinois.edu
redmine=grendon@illinois.edu

if [ $# != 1 ]
then
        MSG="Parameter mismatch.\nRerun like this: $0 <runfile>\n"
        echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s "Variant Calling Workflow failure message" "$redmine"
        exit 1;
fi

set +x
echo -e "\n\n########################################################################################"
echo -e "#############                BEGIN VARIANT CALLING WORKFLOW              ###############"
echo -e "########################################################################################\n\n"

set -x
echo `date`	
scriptfile=$0
runfile=$1
if [ !  -s $runfile ]
then
   MSG="program=$0 stopped at line=$LINENO. $runfile configuration file not found."
   exit 1;
fi
set +x
echo -e "\n\n########################################################################################"
echo -e "#############                CHECKING PARAMETERS                         ###############"
echo -e "########################################################################################\n\n"
set -x 
reportticket=$( cat $runfile | grep -w REPORTTICKET | cut -d '=' -f2 )
outputdir=$( cat $runfile | grep -w OUTPUTDIR | cut -d '=' -f2 )
tmpdir=$( cat $runfile | grep -w TMPDIR | cut -d '=' -f2 )
email=$( cat $runfile | grep -w EMAIL | cut -d '=' -f2 )
thr=$( cat $runfile | grep -w PBSCORES | cut -d '=' -f2 )
nodes=$( cat $runfile | grep -w PBSNODES | cut -d '=' -f2 )
queue=$( cat $runfile | grep -w PBSQUEUE | cut -d '=' -f2 )
sampleinfo=$( cat $runfile | grep -w SAMPLEINFORMATION | cut -d '=' -f2 )
refdir=$( cat $runfile | grep -w REFGENOMEDIR | cut -d '=' -f2 )
refgenome=$( cat $runfile | grep -w REFGENOME | cut -d '=' -f2 )        
dbSNP=$( cat $runfile | grep -w DBSNP | cut -d '=' -f2 )
hapmap=$( cat $runfile | grep -w HAPMAP | cut -d '=' -f2 )
omni=$( cat $runfile | grep -w OMNI | cut -d '=' -f2 )
indels=$( cat $runfile | grep -w INDELS | cut -d '=' -f2 )
phase1=$( cat $runfile | grep -w PHASE1 | cut -d '=' -f2 )
samtools_mod=$( cat $runfile | grep -w SAMTOOLSMODULE | cut -d '=' -f2 )
vcftools_mod=$( cat $runfile | grep -w VCFTOOLSMODULE | cut -d '=' -f2 )
gatkdir=$( cat $runfile | grep -w GATKDIR | cut -d '=' -f2 )
tabix_mod=$( cat $runfile | grep -w TABIXMODULE | cut -d '=' -f2 )
tabix_mod=$( cat $runfile | grep -w TABIXMODULE | cut -d '=' -f2 )
gvcf_mod=$( cat $runfile | grep -w GVCFTOOLMODULE | cut -d '=' -f2 )
ref_local=${refdir}/$refgenome
dbsnp_local=${refdir}/$dbSNP
hapmap_local=${refdir}/$hapmap
omni_local=${refdir}/$omni
indels_local=${refdir}/$indels
phase1_local=${refdir}/$phase1
set +x
echo -e "\n\n##################################################################################" 
echo -e "##################################################################################"        
echo -e "#############                       SANITY CHECK                   ###############"
echo -e "##################################################################################"
echo -e "##################################################################################\n\n"
set -x 
if [ `expr ${#tmpdir}` -lt 1  ]
then
	MSG="Invalid value specified for TMPDIR in the configuration file."
	echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
	exit 1;
fi

if [ ! -d $tmpdir ]
then
    mkdir -p $tmpdir
fi

if [ ! -d  $refdir  ]
then
	MSG="Invalid value specified for REFGENOMEDIR=$refdir in the configuration file."
	echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
	exit 1;
fi

if [ ! -s  $refdir/$refgenome  ]
then
	MSG="Invalid value specified for REFGENOME=$refgenome in the configuration file."
	echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
	exit 1;
fi

if [ ! -s  $refdir/$dbSNP  ]
then
	MSG="Invalid value specified for DBSNP=$dbSNP in the configuration file."
	echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
	exit 1;
fi

if [ ! -s $hapmap_local ]
then
    MSG="$hapmap_local file not found"
    echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"                     
    exit 1
fi

if [ ! -s $omni_local ]
then
    MSG="$omni_local file not found"
    echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"                     
    exit 1
fi

if [ ! -s $phase1_local ]
then
    MSG="$phase1_local file not found"
    echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"                     
    exit 1
fi
if [ ! -d  $gatkdir  ]
then
	MSG="Invalid value specified for GATKDIR=$gatkdir in the configuration file."
	echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
	exit 1;
fi

if [ -z $email ]
then
   MSG="Invalid value for parameter PBSEMAIL=$email in the configuration file"
   echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
   exit 1;
fi

if [ ! -s $sampleinfo ]
then
    MSG="SAMPLEINFORMATION=$sampleinfo  file not found."
    echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
    exit 1;
fi

numsamples=$( wc -l $sampleinfo )	

if [ $numsamples -lt 1 ]
then
    MSG="SAMPLEINFORMATION=$sampleinfo  file is empty."
    echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
    exit 1;	
fi

set +x
echo -e "\n\n########################################################################################"
echo -e "###########                      checking PBS params                      ##################"
echo -e "########################################################################################\n\n"
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
echo -e "\n\n########################################################################################"
echo -e "#############  Everything seems ok. Now setup/configure output folder          #########"
echo -e "########################################################################################\n\n"
set -x
if [ ! -d $outputdir ]
then
        # the output directory does not exist. create it
        mkdir -p $outputdir
fi

TopOutputLogs=${scriptdir}/logs

if [ ! -d $TopOutputLogs ]
then
        # the log directory does not exist. create it
        mkdir -p $TopOutputLogs
fi


generic_qsub_header=$TopOutputLogs/qsubGenericHeader
truncate -s 0 $generic_qsub_header
echo "#!/bin/bash" > $generic_qsub_header
echo "#PBS -q $queue" >> $generic_qsub_header
echo "#PBS -m ae" >> $generic_qsub_header
echo "#PBS -M $email" >> $generic_qsub_header
echo "#PBS -l nodes=$nodes:ppn=$thr" >> $generic_qsub_header

set +x
echo -e "##### let's check that it worked and that the file was created                     ####"
set -x 
if [ ! -s $generic_qsub_header ]
then 
    MSG="$generic_qsub_header is empty"
    echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"
    exit 1;
fi

set +x
echo -e "\n\n########################################################################################"
echo -e "########################################################################################"
echo -e "#####                               MAIN LOOP STARTS HERE                      #########"
echo -e "########################################################################################"
echo -e "########################################################################################\n\n"
set -x 
while read rawvcf
do
    if [ `expr ${#rawvcf}` -lt 1 ]
    then
	set +x
	echo -e "\n\n########################################################################################"
	echo -e "##############                 skipping empty line        ##############################"
	echo -e "########################################################################################\n\n"
	set -x 
    else
	set +x
	echo -e "\n\n########################################################################################"
	echo -e "#####         Processing next line $srawvcf                                ##########"
	echo -e "########################################################################################\n\n"
	set -x 
        if [ ! -s $rawvcf ]
	then
	     MSG="$rawvcf file not found"
	     echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"                     
	     exit 1                
	fi

        sample=$( basename $rawvcf )
	set +x
	echo -e "\n\n########################################################################################"
	echo -e "###   Everything seems in order. Now launching the vqsr script for $sample     ###########"
	echo -e "########################################################################################\n\n"
	set -x 
	qsub1=$TopOutputLogs/qsub.vqsr.$sample
	cat $generic_qsub_header > $qsub1
	echo "#PBS -N vqsr.$sample" >> $qsub1
	echo "#PBS -o $TopOutputLogs/log.vqsr.$sample.ou" >> $qsub1
	echo "#PBS -e $TopOutputLogs/log.vqsr.$sample.in" >> $qsub1
	echo "echo `date`" >> $qsub1
	echo "$scriptdir/recalibrate_vcf.sh $runfile $rawvcf $TopOutputLogs/log.vqsr.$sample.in $TopOutputLogs/log.vqsr.$sample.ou $TopOutputLogs/qsub.vqsr.$sample" >> $qsub1
	echo "echo `date`" >> $qsub1
	`chmod a+r $qsub1`               
	jobid=`qsub $qsub1` 
	
	echo `date`

        if [ `expr ${#jobid}` -lt 1 ]
        then
	     MSG="unable to launch qsub align job for $sample. Exiting now"
	     echo -e "Program $0 stopped at line=$LINENO.\n\n$MSG" | mail -s "[Task #${reportticket}]" "$redmine,$email"                     
	     exit 1        
        
        fi
        
    fi  # end non-empty line
done <  $sampleinfo
set +x
echo -e "\n\n########################################################################################"
echo -e "########################################################################################"
echo -e "#################           MAIN LOOP ENDS HERE                  #######################"
echo -e "########################################################################################"
echo -e "########################################################################################\n\n"

        
echo -e "\n\n########################################################################################"
echo -e "##############                 EXITING NOW                            ##################"	
echo -e "########################################################################################\n\n"
set -x
