#!/bin/bash
#
# realign_varcall_WES.sh <runfile> <sample> <chr> <log.in> <log.ou> <qsub>
# 
redmine=hpcbio-redmine@igb.illinois.edu
if [ $# != 4 ]
then
        MSG="Parameter mismatch. Rerun as: $0 <runfile> <sample> <log> <qsub> "
        echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG" | mail -s 'Variant Calling Workflow failure message' "$redmine"
        exit 1;
fi
set +x
echo -e "\n\n#####################################################################################" >&2 
echo -e "#####  BEGIN ANALYSIS PROCEDURE FOR WES WITHOUT BREAKING UP BY CHROMOSOME  ##########" >&2
echo -e "#####################################################################################\n\n" >&2        

echo -e "\n\n#####################################################################################" >&2        
echo -e "#############             DECLARING VARIABLES                         ###############" >&2
echo -e "#####################################################################################\n\n" >&2        

set -x
echo `date`
scriptfile=$0
runfile=$1
SampleName=$2
elog=$3
command=$4
LOGS="jobid:${PBS_JOBID}\ncommand=$command\nerrorlog=$elog\noutputlog=$olog"


if [ ! -s $runfile ]
then
    MSG="$runfile runfile not found"
    echo -e "program=$scriptfile stopped at line=$LINENO.\nReason=$MSG\n$LOGS" | mail -s "Variant Calling Workflow failure message" "$redmine"
    exit 1;
fi

reportticket=$( cat $runfile | grep -w REPORTTICKET | cut -d '=' -f2 )
rootdir=$( cat $runfile | grep -w OUTPUTDIR | cut -d '=' -f2 )
deliverydir=$( cat $runfile | grep -w DELIVERYFOLDER | cut -d '=' -f2 )
tmpdir=$( cat $runfile | grep -w TMPDIR | cut -d '=' -f2 )
thr=$( cat $runfile | grep -w PBSCORES | cut -d '=' -f2 )
refdir=$( cat $runfile | grep -w REFGENOMEDIR | cut -d '=' -f2 )
indeldir=$( cat $runfile | grep -w INDELDIR | cut -d '=' -f2 )
indelslist=$( cat $runfile | grep -w INDELSLIST | cut -d '=' -f2 )
refgenome=$( cat $runfile | grep -w REFGENOME | cut -d '=' -f2 )
dbsnpdir=$( cat $runfile | grep -w DBSNPDIR | cut -d '=' -f2 )
dbsnp=$( cat $runfile | grep -w DBSNP | cut -d '=' -f2 )
intervals=$( cat $runfile | grep -w INTERVALS | cut -d '=' -f2 )
aligner_parms=$( cat $runfile | grep -w BWAMEMPARAMS | cut -d '=' -f2 )
picardir=$( cat $runfile | grep -w PICARDIR | cut -d '=' -f2 )
samtoolsdir=$( cat $runfile | grep -w SAMDIR | cut -d '=' -f2 )
javadir=$( cat $runfile | grep -w JAVADIR | cut -d '=' -f2 )
markduplicates=$( cat $runfile | grep -w MARKDUPLICATESTOOL | cut -d '=' -f2 | tr '[a-z]' '[A-Z]' )
gatkdir=$( cat $runfile | grep -w GATKDIR | cut -d '=' -f2 ) 
sPL=$( cat $runfile | grep -w SAMPLEPL | cut -d '=' -f2 )
sCN=$( cat $runfile | grep -w SAMPLECN | cut -d '=' -f2 )
sLB=$( cat $runfile | grep -w SAMPLELB | cut -d '=' -f2 )
analysis=$( cat $runfile | grep -w ANALYSIS | cut -d '=' -f2 | tr '[a-z]' '[A-Z]' )
ref_local=${refdir}/$refgenome

outputdir=$rootdir/$SampleName
set +x
echo -e "\n\n##################################################################################" >&2  
echo -e "##################################################################################" >&2          	
echo -e "#######   we will need these guys throughout, let's take care of them now   ######" >&2
echo -e "##################################################################################" >&2  
echo -e "##################################################################################\n\n" >&2          
set -x

SampleDir=$outputdir
AlignDir=$outputdir/align
RealignDir=$outputdir/realrecal
VarcallDir=$outputdir/variant
DeliveryDir=$rootdir/$deliverydir/$SampleName

qcfile=$rootdir/$deliverydir/docs/QC_test_results.txt       # name of the txt file with all QC test results
inputbam=$AlignDir/${SampleName}.wdups.sorted.bam           # name of the bam file that align-dedup produced
dedupsortedbam=${SampleName}.wdups.sorted.bam               # name of the aligned file 
realignedbam=${SampleName}.realigned.bam                    # name of the realigned file
recalibratedbam=${SampleName}.recalibrated.bam              # name of the recalibrated file
rawvariant=${SampleName}.raw.gvcf                           # name of the raw variant file

set +x
echo -e "\n\n##################################################################################" >&2 
echo -e "##################################################################################" >&2        
echo -e "#############                       SANITY CHECK                   ###############" >&2
echo -e "##################################################################################" >&2
echo -e "##################################################################################\n\n" >&2
set -x 
if [ ! -d $tmpdir ]
then
    mkdir -p $tmpdir
fi

if [ `expr ${#SampleName}` -lt 1 ]
then
    MSG="$SampleName sample undefined variable"
    echo -e "$MSG" >> ${rootdir}/logs/mail.${analysis}.FAILURE
    exit 1     
else
    sID=$SampleName
    sPU=$SampleName
    sSM=$SampleName
fi
if [ `expr ${#sLB}` -lt 1 -o `expr ${#sPL}` -lt 1 -o `expr ${#sCN}` -lt 1 ] 
then
    MSG="SAMPLELB=$sLB SAMPLEPL=$sPL SAMPLECN=$sCN at least one of these fields has invalid values. "
    echo -e "$MSG" >> ${rootdir}/logs/mail.${analysis}.FAILURE
    exit 1;
fi

RGparms=$( echo "ID=${sID}:LB=${sLB}:PL=${sPL}:PU=${sPU}:SM=${sSM}:CN=${sCN}" )
rgheader=$( echo -n -e "@RG\t" )$( echo -e "${RGparms}"  | tr ":" "\t" | tr "=" ":" )

if [ ! -d $rootdir ]
then
    MSG="Invalid value specified for OUTPUTDIR=$rootdir in the runfile."
    echo -e "$MSG" >> ${rootdir}/logs/mail.${analysis}.FAILURE
    exit 1;
fi

if [ ! -d $AlignDir ]
then
    MSG="$AlignDir directory not found"
    echo -e "$MSG" >> ${rootdir}/logs/mail.${analysis}.FAILURE
    exit 1;
fi

if [ ! -d $RealignDir ]
then
    MSG="$RealignDir directory not found"
    echo -e "$MSG" >> ${rootdir}/logs/mail.${analysis}.FAILURE
    exit 1;
fi
if [ ! -d $VarcallDir ]
then
    MSG="$VarcallDir directory not found"
    echo -e "$MSG" >> ${rootdir}/logs/mail.${analysis}.FAILURE
    exit 1;
fi
if [ ! -d $DeliveryDir ]
then
    MSG="$DeliveryDir directory not found"
    echo -e "$MSG" >> ${rootdir}/logs/mail.${analysis}.FAILURE
    exit 1;
fi

if [ ! -s $inputbam ]
then
    MSG="$inputbam aligned-dedup file not found"
    echo -e "$MSG" >> ${rootdir}/logs/mail.${analysis}.FAILURE
    exit 1;
fi

set +x
echo -e "\n\n##################################################################################" >&2  
echo -e "##################################################################################" >&2          	
echo -e "#######   REALIGN-RECALIBRATION BLOCK STARTS HERE                           ######" >&2
echo -e "#######   SAMPLE $SampleName " >&2
echo -e "##################################################################################" >&2  
echo -e "##################################################################################\n\n" >&2 
set -x



#echo -e "\n### ploidy variable, its value is 2 for all chr except mitochondrial               ###\n" >&2
#set -x
#if [ $chr == "M" ]
#then
#    ploidy=1
#else
    ploidy=2
#fi
cd $RealignDir

for indelsFile in ${indelslist}
do 
   indelsExists=$( find ${indeldir} -name "${indelsFile}" )
   if [ `expr ${#indelsExist}` -lt 1 ]
   then
      MSG="indels ${indelsFile} were not found in ${indeldir}"
      echo -e "$MSG" >> ${rootdir}/logs/mail.${analysis}.FAILURE
      exit 1;
   fi
   recalparmsindels="${recalparmsindels} -knownSites ${indeldir}/${indelsFile}"  
   realparms="${recalparmsindels} -known ${indeldir}/${indelsFile}"  
done

recalparmsdbsnp="-knownSites ${dbsnpdir}/${dbsnp}"


############################## Indel realignment should be added as an optional stage to the pipeline. This requires adding a variable to the runfile, and also changing the output file name 

set +x
echo -e "########### command one: executing GATK RealignerTargetCreator using known indels ####" 
echo -e "##################################################################################\n\n"
set -x

if [ $analysis == "VC_WITH_REALIGNMENT" ]
then 
	$javadir/java -Xmx8g  -Djava.io.tmpdir=$tmpdir -jar $gatkdir/GenomeAnalysisTK.jar\
       		-R $ref_local\
       		-I $inputbam\
       		-T RealignerTargetCreator\
       		-nt $thr\
       		$realparms\
       		-o ${SampleName}.realignTargetCreator.intervals

	exitcode=$?
        chmod ug=rw ${SampleName}.realignTargetCreator.intervals	
	echo `date`
	if [ $exitcode -ne 0 ]
        then
       		MSG="RealignerTargetCreator command failed exitcode=$exitcode. realignment for sample $SampleName.$chr. stopped"
                echo -e "$MSG" >> ${rootdir}/logs/mail.${analysis}.FAILURE
       		exit $exitcode;
	fi

	if [ ! -s ${SampleName}.realignTargetCreator.intervals ]
        then
       		echo -e "${SampleName}\tREALIGNMENT\tWARN\t${SampleName}.RealignTargetCreator.intervals is an empty file. Skipping Indel realignment cmd\n" >> $qcfile
       		ln -s $dedupsortedbam $RealignDir/$realignedbam
	else 
		set +x
		echo -e "\n\n##################################################################################" 
		echo -e "########### command two: executing GATK IndelRealigner and generating BAM    #####"
		echo -e "##################################################################################\n\n"
		set -x
		$javadir/java -Xmx8g -Djava.io.tmpdir=$tmpdir -jar $gatkdir/GenomeAnalysisTK.jar \
      			-R $ref_local -I $dedupsortedbam -T IndelRealigner $realparms \
      			--targetIntervals ${SampleName}.realignTargetCreator.intervals \
      			-o $realignedbam
		
		exitcode=$?
                chmod ug=rw $realignedbam
		set +x
		echo -e "\n\n##################################################################################" 
		echo -e "########### command three: sanity check for GATK IndelRealigner                  #####"
		echo -e "##################################################################################\n\n"
		set -x
		echo `date`
		if [ $exitcode -ne 0 ]; then
       			MSG="indelrealigner command failed exitcode=$exitcode. realignment for sample $SampleName stopped"
                        echo -e "$MSG" >> ${rootdir}/logs/mail.${analysis}.FAILURE
       			exit $exitcode;
		fi
		
		if [ -s $realignedbam ]; then
	    		set +x		     
	    		echo -e "### the file was created. But we are not done.     #############"
	    		echo -e "### sometimes we may have a BAM file with NO alignmnets      ###"
	    		set -x 			
	    		numAlignments=$( $samtoolsdir/samtools view -c $realignedbam ) 
	    		echo `date`
	    		if [ $numAlignments -eq 0 ]; then
				echo -e "${SampleName}\tREALIGNMENT\tFAIL\tGATK IndelRealigner command did not produce alignments for $realignedbam\n" >> $qcfile	    
				MSG="GATK IndelRealigner command did not produce alignments for $realignedbam"
                                echo -e "$MSG" >> ${rootdir}/logs/mail.${analysis}.FAILURE
				exit 1;
	    		else
				echo -e "####### $realignedbam seems to be in order ###########"
	    		fi
		else 
	    		MSG="indelrealigner command did not produce a file $realignedbam"
                        echo -e "$MSG" >> ${rootdir}/logs/mail.${analysis}.FAILURE
	    		exit 1;          
		fi
	fi
else 
	realignedbam=$dedupsortedbam	#if no realignment required, then use the dedupsortedbam file as input to the next step. This is to avoid introducing a new variable
fi

echo `date`     
set +x
echo -e "\n\n##################################################################################" 
echo -e "########### command four: run GATK BaseRecalibrator using known indels and dbSNP    ##"
echo -e "##################################################################################\n\n"
set -x 
$javadir/java -Xmx16g  -Djava.io.tmpdir=$tmpdir -jar $gatkdir/GenomeAnalysisTK.jar \
         -T BaseRecalibrator \
         -R $ref_local \
         -I $realignedbam \
         $recalparmsindels \
	 $recalparmsdbsnp \
         --out $SampleName.recal_report.grp \
         -nct $thr 
exitcode=$?
chmod ug=rw $SampleName.recal_report.grp

echo `date`
if [ $exitcode -ne 0 ]
then
	MSG="BaseRecalibrator command failed exitcode=$exitcode. recalibration for sample $SampleName stopped"
        echo -e "$MSG" >> ${rootdir}/logs/mail.${analysis}.FAILURE
	exit $exitcode;
fi
if [ ! -s $SampleName.recal_report.grp ]
then
	echo -e "${SampleName}\tRECALIBRATION\tWARN\t$SampleName.recal_report.grp is an empty file. Skipping recalibration cmd\n" >> $qcfile
        ln -s $dedupsortedbam $RealignDir/$recalibratedbam
else
	set +x 
	echo -e "\n\n##################################################################################" 
	echo -e "########### command five: GATK BQSR step                                         #####"
	echo -e "##################################################################################\n\n"
	set -x

        $javadir/java -Xmx8g  -Djava.io.tmpdir=$tmpdir -jar $gatkdir/GenomeAnalysisTK.jar \
                -R $ref_local \
                -I $realignedbam \
                -T PrintReads \
                -BQSR $SampleName.recal_report.grp \
                --out $recalibratedbam \
                -nct $thr
        exitcode=$?
        chmod ug=rw $recalibratedbam

	set +x
	echo -e "\n\n##################################################################################" 
	echo -e "########### command six: sanity check for GATK BQSR step                        #####"
	echo -e "##################################################################################\n\n"
	set -x

	if [ -s $recalibratedbam ]
	then     
	    echo -e "### the file was created. But we are not done.     #############"
	    echo -e "### sometimes we may have a BAM file with NO alignmnets      ###"
	    numAlignments=$( $samtoolsdir/samtools view -c $recalibratedbam ) 

	    echo `date`
	    if [ $numAlignments -eq 0 ]
	    then
                echo -e "${SampleName}\tRECALIBRATION\tFAIL\tBQSR Recalibrator command did not produce alignments for $recalibratedbam\n" >> $qcfile	    
		MSG="GATK BQSR Recalibrator command did not produce alignments for $recalibratedbam"
                echo -e "$MSG" >> ${rootdir}/logs/mail.${analysis}.FAILURE
		exit 1;
	    else
	        set +x
		echo -e "####### $realignedbam seems to be in order ###########"
		set -x 
	    fi
	else 
	    MSG="GATK BQSR Recalibrator command did not produce a file $recalibratedbam"
            echo -e "$MSG" >> ${rootdir}/logs/mail.${analysis}.FAILURE
	    exit 1;          
	fi	

fi      
echo `date` 
set +x
echo -e "\n\n##################################################################################"
echo -e "#############     END REALIGN-RECALIBRATION BLOCK                         ############"
echo -e "##################################################################################\n\n"          


echo -e "\n\n##################################################################################"  
echo -e "##################################################################################"	
echo -e "##################################################################################"        
echo -e "#############    GATK VARIANT CALLING "
echo -e "#############    SAMPLE $SampleName "
echo -e "##################################################################################"
echo -e "##################################################################################"  
echo -e "##################################################################################\n\n"

echo `date`        

`find . -type d | xargs chmod -R 770`
`find . -type f | xargs chmod -R 660`


cd $VarcallDir

echo -e "\n\n##################################################################################"            
echo -e "########### command one: executing GATK HaplotypeCaller command         ##########" 
echo -e "##################################################################################\n\n"
set -x


$javadir/java -Xmx16g  -Djava.io.tmpdir=$tmpdir -jar $gatkdir/GenomeAnalysisTK.jar \
	 -T HaplotypeCaller \
	 -R $ref_local \
	 --dbsnp $dbsnp_local \
	 -I $RealignDir/$recalibratedbam \
	 --emitRefConfidence GVCF \
	 -gt_mode DISCOVERY \
	 -A Coverage -A FisherStrand -A StrandOddsRatio -A HaplotypeScore -A MappingQualityRankSumTest -A QualByDepth -A RMSMappingQuality -A ReadPosRankSumTest \
	 -stand_call_conf 30 \
	 -stand_emit_conf 30 \
	 --sample_ploidy $ploidy \
	 -nt 1 -nct $thr \
	 -L $intervals\
	 -o $rawvariant

exitcode=$?
chmod ug=rw $rawvariant
echo `date`

if [ $exitcode -ne 0 ]
then
	MSG="GATK HaplotypeCaller command failed exitcode=$exitcode for $rawvariant"
        echo -e "$MSG" >> ${rootdir}/logs/mail.${analysis}.FAILURE
	exit $exitcode;
fi
if [ ! -s $rawvariant ]
then
	echo -e "${SampleName}\tVCALL\tFAIL\tHaplotypeCaller command did not produce results for $rawvariant\n" >> $qcfile	    
	MSG="GATK HaplotypeCaller command did not produce results for $rawvariant"
        echo -e "$MSG" >> ${rootdir}/logs/mail.${analysis}.FAILURE
	exit 1;
fi
set +x
echo -e "\n\n##################################################################################"
echo -e "#############       END VARIANT CALLING BLOCK                         ############"        
echo -e "##################################################################################\n\n"


echo -e "\n\n##################################################################################"  
echo -e "##################################################################################"		
echo -e "##################################################################################"        
echo -e "#############   WRAP UP                                               ############"        
echo -e "##################################################################################"
echo -e "##################################################################################"  
echo -e "##################################################################################\n\n"	
set -x
echo `date`
 
#cp $RealignDir/${SampleName}.$chr.recalibrated.bam   $DeliveryDir

# we will merge all variant files for this sample and copy that file to delivery
#cp $VarcallDir/rawvariant=${SampleName}.$chr.raw.vcf $DeliveryDir  
set +x
echo `date`
echo -e "\n\n##################################################################################"
echo -e "#############    DONE PROCESSING SAMPLE $SampleName"
echo -e "##################################################################################\n\n"
set -x

MSG="GATK HaplotypeCaller finished successfully for ${SampleName}"
echo -e "$MSG" >> ${rootdir}/logs/mail.${analysis}.SUCCESS

`find . -type d | xargs chmod -R 770`
`find . -type f | xargs chmod -R 660`

