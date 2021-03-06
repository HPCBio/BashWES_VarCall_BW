Changelog
=========

June 22, 2016:
- The tool SNVMix is not used, so removed from the run fil
- The tool SAMBAMBA is also not used
- Deleted all mentions of INPUTDIR and SAMPLEDIR 
- The following options are not in use:
-  	MEMPROFCOMMAND 
- 	IGVDIR
- 	PBSPROJECTID 
-	PBSQUEUEWGEN    
- 	SKIPVCALL
- 	INPUTTYPE 
- 	DISEASE 
- 	GROUPNAMES	
- 	LABINDEX 
- 	LANEINDEX
- 	SOMATIC_CALLER
- 	BAM2FASTQFLAG
- 	BAM2FASTQPARMS
- 	REVERTSAM
- 	FASTQCFLAG
- 	FASTQCPARMS
- 	CHUNKFASTQ
- 	BWAPARAMS
- 	NOVOPARAMS
- 	BLATPARAMS
- 	REALIGNPARMS
- 	REMOVE_DUP
- 	REORDERSAM
- 	REALIGNORDER
- 	PEDIGREE
- 	VARIANT_TYPE
- 	UNIFIEDGENOTYPERPARMS
- 	SNVMIX2PARMS
- 	SNVMIX2FILTER 
- 	EPILOGUE
- 	GENOMEBUILD
- 	EMIT_ALL_SITES
- 	DEPTH_FILTER
- 	TARGETTED
- 	KGENOME
-	ONTARGET
-	NOVOINDEX
-	BWAMEMINDEX
-	NOVODIR
- 	BWADIR
-	BWAMEMDIR
- 	SNVMIXDIR
- 	PBSCPUOTHEREXOME
- 	PBSCPUOTHERWGEN
- 	PBSCPUOTHEREXOME
- 	CPUALIGNWGEN
- 	SNV_CALLER
- 	RECALIBRATOR

New and changed parameters and meanings:
- PBSWALLTIME : wall time for the job (still need to account for this in the workflow code)
- PBSCORES: instead of PBSTHREADS
- PBSQUEUE: instead of PBSQUEUEEXOME
- TMPDIR: folder for temporary files
- MAP_CUTOFF: Minimum quality cutoff
- DUP_CUTOFF: Maximum duplication level cutoff
- BWADIR : Directory of the BWA MEM
- CHRNAMES: Instead of CHRINDEX to represent the crhomosomes/ contigs under consideration (The existing names are approapriate for use with soybeans as is)
- SAMPLEINFORMATION: This entry was repeated twice in the original file. Just keep the entry directing to the sampleinfo file
- BWAINDEX: points to the indexed reference genome, and should be passed to the align_dedup.sh
- SCRIPTDIR
- OMNI: This is another database that is valuable for VQSR for human data (VQSR is done differently in plant datasets though!)
- ANALYSIS: This parameter specifies which analysis is needed. It can be 'ALIGN', 'ALIGNMENT', OR 'ALIGN_ONLY' to only do the alignment stage of the pipeline; or 'VC_WITH_REALIGNMETN' to do a complete Variant Calling with realignment; or anything else to do a complete Variant Calling without the realignment stage

Code changes:
- pbs.MERGE
- Use the variable alignjobid : instead of jobid, and save to pbs.ALIGN and pbs.summary_dependencies (to solve problems in deducing the right pbs job id in the queue)
- ALIGNERTOOL: checks for the tools used for alignment (instead of the variable ALIGNER 
- gatkdir: this is introduced instead of gatk_dir
- NOVOCRAFT is introduced as replacement for NOVOSORT to allow for the use of both novoalign and novosort
- A new variable INDELDIR: directory of known indels split by chromosome name
- The script 'merge_vcf_and_bam.sh' has been modified to merge_vcf.sh, so that it only does the merging (by commenting out all instructions relevant to merging bams). If variants can be called on per chromosome basis, then no real value is added from merging the bams, except maybe the convenience of the client who might consider calling variants again from them. A little later, this functionality can be added, by copying the relevant code pieces from this script to a new script with a more meaningful name. 
- Group read/write permissions were added by settingthe ACL (via setfacl command). The easier alternative would have been simply setting:  umask 0003

To do:
- The old pipeline assumes that all tools are module loaded first then called directly. For more generality, the complete path of each tool is specified instead: SAMMODULE is replaced with SAMDIR, and the variable name is samtools. Still need to check the full path of each tool and update that the executable actually exists. So far, the following paths have been integrated:
-	BWAMEMDIR
-	SAMTOOLSDIR
-	NOVOCRAFTDIR
-	SAMBLASTERDIR (just to allow the option, not sure if will be of value)

Analysis types supported:
* Currently, there are the following options:
-  ALIGNMENT, ALIGN, ALIGN_ONLY : to only do alignment. The pipeline stops at this stage
-  Anything else would cause the complete gatk pipeline to run until variant calling stage

* Useful analysis options (to do, but check variables naming first!):
-  REALIGN_ONLY: alignment + indel realignment + variant calling + variant recalibration
-  RECALIBRATE_ONLY: alignment + BQSR + variant calling + variant recalibration
-  VCALL: alignment + realignment + recalibration + variant calling
-  FULL: run the entire pipeline: alignment + realignment + recalibration + variant calling + variant recalibration

* Useful debugging options:
It would be handy if the pipeline could do a single piece of work as desired. For example:
-  ALIGN: only perform alignment and exit ---> already implemented
-  REALIGN: only perform realignment
-  RECALIBRATE: only perform recalibration
-  VCALL_ONLY: to only do variant calling
-  VQSR_ONLY: to only do variant recalibration

The chromosome names within the indeldir (the dbSNP files) need to be named in the following convention: *.<chrnumber>.vcf
Make sure that the chromosome names within the dbSNPfiles, the reference, and the Runfile are all labelled the same, ie. chr01, chr1 Chr01, Chr1  Gm01, Gm1, 1, 01,  etc.
