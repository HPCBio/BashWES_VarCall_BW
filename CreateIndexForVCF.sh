#!/bin/bash
set -x


## set paths.

JobName=$1
OUT_DIR_ROOT=$2
PathToFiles=$3 
JAVADIR=/opt/java/jdk1.8.0_51/bin
GATK_PATH=/projects/sciteam/baib/builds/gatk-3.7.0
REF=/projects/sciteam/baib/GATKbundle/July1_2017/LSM_July1_2017/human_g1k_v37_decoy.SimpleChromosomeNaming.fasta

OUT_DIR=$OUT_DIR_ROOT/$JobName
mkdir $OUT_DIR
mkdir $OUT_DIR/logs
mkdir $OUT_DIR/tmp
LOGS=$OUT_DIR/logs
FILES=${PathToFiles}/SRR*/*.g.vcf

JOBLIST=$OUT_DIR/logs/${JobName}.Anisimov.joblist
truncate -s 0 ${JOBLIST}
ANISIMOV_PATH=/projects/sciteam/baib/builds/Scheduler

if [ ! -d  $ANISIMOV_PATH  ]
then
        MSG="Invalid value specified for ANISIMOV_PATH=$ANISIMOV_PATH."
        echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG"
        exit 1;
fi

if [ ! -d  $OUT_DIR  ]
then
        MSG="Invalid value specified for OUT_DIR=$OUT_DIR."
        echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG"
        exit 1;
fi

if [ ! -s  $REF  ]
then
        MSG="Invalid value specified for REF=$REF."
        echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG"
        exit 1;
fi

if [ ! -s  $GATK_PATH  ]
then
        MSG="Invalid value specified for GATK_PATH=$GATK_PATH."
        echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG"
        exit 1;
fi

if [ `expr ${#FILES}` -lt 1 ]
then
        MSG="Invalid value specified for FILES."
        echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG"
        exit 1;
fi




### construct the  fake SelectHeaders tasks for all the gvcf files
for file in $FILES
do
   file_name=`basename ${file} .g.vcf`

   echo -e "nohup /opt/java/jdk1.8.0_51/bin/java -Xmx512m -Djava.io.tmpdir=$OUT_DIR/tmp -jar $GATK_PATH/GenomeAnalysisTK.jar -T SelectHeaders -R $REF -V ${file} -o ${file}.SmallHeader -hn INFO >  $OUT_DIR/logs/log.${file_name}.anisimov.command " > $OUT_DIR/logs/${file_name}.anisimov.command
   chmod ug=rwx $OUT_DIR/logs/${file_name}.anisimov.command
   echo "$OUT_DIR/logs ${file_name}.anisimov.command" >> ${JOBLIST}

   (( file_counter++ ))
done

# calculate the number of nodes needed, to be numbers of g.vcf files divided by 32 + 1
# divide by 32 because we will put 32 files per node
# and +1 for launcher or an odd file
numnodes=$((file_counter/32+1))

# number of processing elements for aprun = num files + 1 for launcher
numPE=$((file_counter+1))


## PBS Torque options
qsub1=$OUT_DIR/logs/${JobName}.Anisimov.qsub
echo "#!/bin/bash" > $qsub1
echo "#PBS -A baib" >> $qsub1
echo "#PBS -l nodes=${numnodes}:ppn=32:xe" >> $qsub1
echo "#PBS -l walltime=05:00:00" >> $qsub1
echo "#PBS -q high" >> $qsub1
echo "#PBS -l flags=commtransparent" >>  $qsub1
echo "#PBS -e $OUT_DIR/logs/${JobName}.er" >> $qsub1
echo "#PBS -o $OUT_DIR/logs/${JobName}.ou" >> $qsub1
echo "#PBS -N ${JobName}.get_idx" >> $qsub1
echo "#PBS -M lmainzer@illinois.edu" >> $qsub1
echo "#PBS -m ae" >> $qsub1
echo -e "\n" >> $qsub1

echo "aprun -n $numPE $ANISIMOV_PATH/scheduler.x $JOBLIST /bin/bash -noexit > $OUT_DIR/logs/log.${JobName}.Anisimov " >> $qsub1

qsub $qsub1


echo "Jobs scheduled. Done."
echo `date`
