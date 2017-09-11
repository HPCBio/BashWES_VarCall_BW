#!/bin/bash
set -x



## set paths.

BatchName=$1
OUT_DIR_ROOT=$2
PathToFiles=$3 
JAVADIR=/opt/java/jdk1.8.0_51/bin
GATK_PATH=/projects/sciteam/baib/builds/gatk-3.7.0
REF=/projects/sciteam/baib/GATKbundle/July1_2017/LSM_July1_2017/human_g1k_v37_decoy.SimpleChromosomeNaming.fasta
INTERVALS=/projects/sciteam/baib/GATKbundle/July1_2017/LSM_July1_2017/baylorwashu_broad.SimpleChromosomeNaming.Top30.bed

OUT_DIR=$OUT_DIR_ROOT/$BatchName
mkdir $OUT_DIR
mkdir $OUT_DIR/logs
mkdir $OUT_DIR/tmp
LOGS=$OUT_DIR/logs
VAR=$OUT_DIR/variants
FILES=${PathToFiles}/SRR*/*.g.vcf

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




### construct the list of variant files for GenotypeGVCFs

VariantFileList=""
for file in $FILES
do
   VariantFileList=${VariantFileList}" --variant ${file}"
done

#echo "Executing Anisimov Scheduler on $JOBLIST..."

## PBS Torque options
qsub1=$OUT_DIR/logs/${BatchName}.joint_genotyping.qsub
echo "#!/bin/bash" > $qsub1
echo "#PBS -A baib" >> $qsub1
echo "#PBS -l nodes=1:ppn=32:xe" >> $qsub1
echo "#PBS -l walltime=02:00:00" >> $qsub1
echo "#PBS -q high" >> $qsub1
echo "#PBS -e $OUT_DIR/logs/${BatchName}.er" >> $qsub1
echo "#PBS -o $OUT_DIR/logs/${BatchName}.ou" >> $qsub1
echo "#PBS -N ${BatchName}.joint_genotyping" >> $qsub1
echo "#PBS -M lmainzer@illinois.edu" >> $qsub1
echo "#PBS -m ae" >> $qsub1
echo -e "\n" >> $qsub1

echo "aprun -N 1 $JAVADIR/java -Xmx32g -Djava.io.tmpdir=$OUT_DIR/tmp -jar $GATK_PATH/GenomeAnalysisTK.jar -T GenotypeGVCFs -R $REF ${VariantFileList} -o $OUT_DIR/${BatchName}.JointGenotypingCalls.vcf -L $INTERVALS -nt 32  --disable_auto_index_creation_and_locking_when_reading_rods " >> $qsub1

#ANISIMOV_PATH=/projects/sciteam/baib/builds/Scheduler

#if [ ! -d  $ANISIMOV_PATH  ]
#then
#        MSG="Invalid value specified for ANISIMOV_PATH=$ANISIMOV_PATH."
#        echo -e "program=$0 stopped at line=$LINENO. Reason=$MSG"
#        exit 1;
#fi

#source /opt/modules/default/init/bash
#
#echo "aprun -n $PROCS -d $ppn $ANISIMOV_PATH/scheduler.x $JOBLIST /bin/bash > $LOGS/output.log" >> $qsub1
#qsub $qsub1


echo "Jobs scheduled. Done."
echo `date`
