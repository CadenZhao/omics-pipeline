#!/usr/bin/bash


# 帮助文档
helpdoc(){
    cat <<EOF
Description:

    This shellscript is used to perform bulk RNA-seq pipeline mainly using STAR
    output: 1. sorted and indexed BAM file; 2. gene count table for each sample, merged count table; 3. TPM table

Usage:

    $0 [ -g <genome star index> | -G <genome fasta file> ] -a <GTF file> -i <fastq directory> -o <output directory> -t <SE or PE> -d <adaptor directory>

Option:
    -h    show help information

    -g    genome star index directory. It is generated by STAR --runMode genomeGenerate.
          Index will be built from fasta file if it's not set
    -G    genome fasta file. It will be ignored if -g be assigned and STAR index is exting
    -a    annotation GTF file. It should not be a compressed file
    -i    input fastq file directory. All file should be compressed with suffix .fastq.gz.
          Program will find all fastq files to perform pipeline
    -o    output directory.
    -t    type of library. SE or PE
    -d    illumina Hiseq series sequencing platform adaptor directory, may be <path to trimmomatic>/adaptors
          if you installed trimmomatic by conda, it may be: <path to anaconda installed directory>/envs/<environment name>/share/trimmomatic/adapters/

    -@    number of threads. Default: 8 [Optional]
    -l    read max length.  Default: 100 [Optional]

    -T    trimmomatic path. Default: trimmmomatic in current environmental variables [Optional]
    -q    fastqc path. Default: fastqc in current environmental variables [Optional]
    -Q    multiqc path. Default: multiqc in current environmental variables [Optional]
    -s    STAR path. Default: STAR in current environmental variables [Optional]
    -S    samtools path. Default: samtools in current environmental variable [Optional]
EOF
}

# 若无指定任何参数则输出帮助文档
if [ $# = 0 ]
then
    helpdoc
    exit 1
fi


################################################Arguments############################################

# 设置默认参数 
thread=8
read_max_length=100

# 传参
while getopts "hg:G:a:i:o:t:d:@:l:T:q:Q:s:S:" opt
do
    case $opt in
        h)
            helpdoc
            exit 0
            ;;
        g)
            genome_index_dir=$OPTARG
            ;;
        G)
            genome_fasta=$OPTARG 
            ;;
        a)
            gtf_file=$OPTARG
            if [ ! -f ${gtf_file} ]; then
                printf "ERROR! No such file: ${gtf_file}\n"
                helpdoc
                exit 1
            fi
            ;;
        i)
            fastq_dir=${OPTARG%"/"}
            if [ ! -d ${fastq_dir} ]; then
                printf "ERROR! No such directory: ${fastq_dir}\n"
                helpdoc
                exit 1
            fi
            ;;
        o)
            out_dir=${OPTARG%"/"}
            if [ ! -d ${out_dir} ]; then
                printf "ERROR! No such directory: ${out_dir}\n"
                helpdoc
                exit 1
            fi
            ;;
        t)
            type_of_lib=$OPTARG
            if [ "${type_of_lib}" != "SE" ] && [ "${type_of_lib}" != "PE" ]; then
                printf "ERROR! Unknown library type: ${type_of_lib}\n" 
                helpdoc
                exit 1
            fi
            ;;
        d)
            adaptor_dir=${OPTARG%"/"}
            if [ ! -d ${adaptor_dir} ]; then
                printf "ERROR! No such directory: ${adaptor_dir}\n"
                helpdoc
                exit 1
            fi
            ;;
        @)
            thread=$OPTARG
            if ! [[ "${thread}" =~ ^[0-9]+$ ]]; then
                printf "ERROR! Unkown thread number: ${thread}. Only interger is allowed\n"
                helpdoc
                exit 1
            fi
            ;;
        l)
            read_max_length=$OPTARG
            if ! [[ "${thread}" =~ ^[0-9]+$ ]]; then
                printf "ERROR! Unkown read length: ${read_max_length}. Only interger is allowed\n"
                helpdoc
                exit 1
            fi
            ;;
        T)
            trimmomatic=$OPTARG
            if [ ! -f ${trimmomatic} ]; then
                printf "ERROR! Wrong trimmomatic path: ${trimmomatic}\n"
                helpdoc
                exit 1
            fi
            ;;

        q)
            fastqc=$OPTARG
            if [ ! -f ${fastqc} ]; then
                printf "ERROR! Wrong fastqc path: ${fastqc}\n"
                helpdoc
                exit 1
            fi
            ;;
        Q)
            multiqc=$OPTARG
            if [ ! -f ${multiqc} ]; then
                printf "ERROR! Wrong multiqc path: ${multiqc}\n"
                helpdoc
                exit 1
            fi
            ;;
        s)
            STAR=$OPTARG
            if [ ! -f ${STAR} ]; then
                printf "ERROR! Wrong STAR path: ${STAR}\n"
                helpdoc
                exit 1
            fi
            ;;
        s)
            samtools=$OPTARG
            if [ ! -f ${samtools} ]; then
                printf "ERROR! Wrong samtools path: ${samtools}\n"
                helpdoc
                exit 1
            fi
            ;;
        ?)
            printf "ERROR! Unknown option: $opt\n"
            helpdoc
            exit 1
            ;;
    esac
done

printf "Running parameters: $0 $*\n"


################################################exception test############################################

# 检查必须参数是否传参了，少任何一个退出
if [ "${gtf_file}" == "" ] || [ "${fastq_dir}" == "" ] || [ "${out_dir}" == "" ] || [ "${type_of_lib}" == "" ]; then
    printf "ERROR: -a, -i, -o and -t are required.  Please fill them all\n"
    helpdoc
    exit 1
fi

# 检查-g和-G的传参情况，如果-g对了的话直接过, 填了但是没填对退出，没填的话再检查-G，用-G来建index 
if [ "${genome_index_dir}" != "" ]; then
    if [ -d ${genome_index_dir} ]; then
        printf "Using STAR index (-g) to perform alignment.  Genome reference fasta file (-G) will be omitted.\n"
    else
        printf "ERROR: STAR index directory not found: \'${genome_index_dir}\'.  Please set a right STAR index path\n"
        helpdoc
        exit 1
    fi
else
    if [ "${genome_fasta}" == "" ]; then
        printf "ERROR: -g or -G must be set.  Please set at least one\n"
        helpdoc
        exit 1
    elif [ ! -f ${genome_fasta} ]; then
        printf "ERROR: unknown file: \'${genome_fasta}\'\n"
        helpdoc
        exit 1
    else
        printf "Using reference genome fasta file to build STAR genome index before aligning...\n"
        genome_index_dir=${genome_fasta%".fa"}.star.index
        mkdir -p ${genome_index_dir}
        STAR --runMode genomeGenerate --genomeFastaFiles ${genome_fasta} --sjdbGTFfile ${gtf_file} --genomeDir ${genome_index_dir} \
             --runThreadN ${thread} --sjdbOverhang $[ ${read_max_length} - 1 ]
    fi
fi


################################################initialization############################################

# mkdir output directory structure
mkdir -p ${out_dir}/fastq_trimmed
mkdir -p ${out_dir}/qc/fastqc
mkdir -p ${out_dir}/qc/multiqc
mkdir -p ${out_dir}/alignment/star
mkdir -p ${out_dir}/quantification

# get current script directory
BASEDIR=$(dirname "$0")

out_dir_fastq_trimmed=${out_dir}/fastq_trimmed
out_dir_fastqc=${out_dir}/qc/fastqc
out_dir_multiqc_fq=${out_dir}/qc/multiqc/fastqc_report
out_dir_align=${out_dir}/alignment/star
out_dir_multiqc_star=${out_dir}/qc/multiqc/star_report
out_dir_quantification=${out_dir}/quantification

# get unique sample ID from input fastq directory.  Prefix is name before .fasta.gz for SE, before _1.fastq.gz or _2.fastq.gz for PE 
if [ ${type_of_lib} == "SE" ]; then
    sample_prefix_list=`find ${fastq_dir} -type f -name "*.fastq.gz" | awk '{gsub(/\.fastq\.gz$/, "", $1); print $1}'` && printf "***Performing Single End pipeline...***\n"
else
    sample_prefix_list=`find ${fastq_dir} -type f -name "*_1.fastq.gz" | awk '{gsub(/\.fastq\.gz$/, "", $1); print $1}'` && printf "***Performing Paired End pipeline...***\n"
fi


################################################qc############################################

## trim adaptor and filter low quality reads 
n=1
n_sample=`echo ${sample_prefix_list} | wc -w`
printf "***Trimming adaptor and filtering low quality reads (${type_of_lib} mode)...***\n"
for sample_prefix in ${sample_prefix_list}
do
    sampleID=`basename ${sample_prefix}`
    printf "***Processing: ${sampleID} (${n}/${n_sample})***\n"
    if [ ${type_of_lib} == "SE" ]; then
        trimmomatic ${type_of_lib} -threads ${thread} -phred33 -trimlog ${out_dir_fastq_trimmed}/${sampleID}.trimmomatic.log \
        ${sample_prefix}.fastq.gz ${out_dir_fastq_trimmed}/${sampleID}.trimmed.fastq.gz \
        ILLUMINACLIP:${adaptor_dir}/TruSeq3-${type_of_lib}.fa:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:50 || exit 1
    else
        trimmomatic ${type_of_lib} -threads ${thread} -phred33 -trimlog ${out_dir_fastq_trimmed}/${sampleID}.trimmomatic.log \
        ${sample_prefix}_1.fastq.gz ${sample_prefix}_2.fastq.gz \
        ${out_dir_fastq_trimmed}/${sampleID}_1.trimmed.fastq.gz ${out_dir_fastq_trimmed}/${sampleID}_1.abandoned.fastq.gz \
        ${out_dir_fastq_trimmed}/${sampleID}_2.trimmed.fastq.gz ${out_dir_fastq_trimmed}/${sampleID}_2.abandoned.fastq.gz \
        ILLUMINACLIP:${adaptor_dir}/TruSeq3-${type_of_lib}.fa:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:50 || exit 1
    fi
    n=$[ $n + 1 ]
done
printf "***trimmomatic done***\n"

# fastqc
printf "***Starting QC using Fastqc...***\n"
time fastqc -o ${out_dir_fastqc} -t ${thread} ${fastq_dir}/*.fastq.gz && printf "***fastqc for raw fastq done***\n"
time fastqc -o ${out_dir_fastqc} -t ${thread} ${out_dir_fastq_trimmed}/*.fastq.gz && printf "***fastqc for trimmed fastq done***\n"

# multiqc
printf "***Collecting QC results using Multiqc...***\n"
time multiqc -o ${out_dir_multiqc_fq} ${out_dir_fastqc} && printf "***multiqc done***\n"


################################################batch alignment#############################################

# STAR fixed parameter configuration
fixed_parameters="--quantMode TranscriptomeSAM GeneCounts \
                  --outSAMtype BAM Unsorted \
                  --genomeLoad LoadAndKeep \
                  --outFilterType BySJout \
                  --outSAMattributes NH HI AS NM MD \
                  --outFilterMultimapNmax 20 \
                  --alignSJoverhangMin 8 --alignSJDBoverhangMin 1 \
                  --outFilterMismatchNmax 999 \ 
                  --alignIntronMin 20 --alignIntronMax 1000000 --alignMatesGapMax 1000000 \
                  --outSAMattrIHstart 0 --outSAMstrandField intronMotif \
                  --outReadsUnmapped Fastx \
                 "

# batch processing: align, sort, index
count=1
for sample_prefix in ${sample_prefix_list}
do
    # make output directory for each sample
    sampleID=`basename ${sample_prefix}`
    mkdir -p ${out_dir_align}/${sampleID}

    # alignment
    printf "***Aligning: ${i} (${count}/${n_sample}) (using trimmed fastq file to perform alignment)***\n"
    if [ ${type_of_lib} == "SE" ]; then
        time STAR ${fixed_parameters} \
             --runMode alignReads --runThreadN ${thread} \
             --genomeDir ${genome_index_dir} \
             --readFilesIn ${out_dir_fastq_trimmed}/${sampleID}.trimmed.fastq.gz \
             --readFilesCommand zcat \
             --outFileNamePrefix ${out_dir_align}/${sampleID}/${sampleID}. && printf "***Alignment done: ${sampleID}***\n"
    elif [ ${type_of_lib} == "PE" ]; then
        time STAR ${fixed_parameters} \
             --runMode alignReads --runThreadN ${thread} \
             --readFilesIn ${out_dir_fastq_trimmed}/${sampleID}_1.trimmed.fastq.gz ${out_dir_fastq_trimmed}/${sampleID}_2.trimmed.fastq.gz \
             --readFilesCommand zcat \
             --genomeDir ${genome_index_dir} \
             --outFileNamePrefix ${out_dir_align}/${sampleID}/${sampleID}. && printf "***Alignment done: ${sampleID}***\n"
    fi

    # bam sort 
    time samtools sort -@ ${thread} \
        -o ${out_dir_align}/${sampleID}/${sampleID}.Aligned.out.sorted.bam \
        -T ${out_dir_align}/${sampleID}/${sampleID} \
           ${out_dir_align}/${sampleID}/${sampleID}.Aligned.out.bam && printf "***BAM sorting done***\n"

    # bam index 
    time samtools index ${out_dir_align}/${sampleID}/${sampleID}.Aligned.out.sorted.bam && printf "***BAM indexing done***\n"

    # format the gene count table: remove the fist 4 rows, insert sample and field information in the first line
    tail -n +5 ${out_dir_align}/${sampleID}/${sampleID}.ReadsPerGene.out.tab | \
    sed "1 i\ensembl_id\t${sampleID}\t${sampleID}_sense\t${sampleID}_antisense" - > \
        ${out_dir_align}/${sampleID}/${sampleID}.ReadsPerGene.out.formatted.tsv

    count=$[ ${count} + 1 ]
done

# multiqc for STAR results
printf "***Performing multiqc for STAR results***\n"
time multiqc -o ${out_dir_multiqc_star} ${out_dir_align} && printf "***Multiqc for STAR done***\n"


############################################count2TPM#############################

# merge formatted gene count table and only keep total reads results for every sample (i.e., not treatted as strand specific library)
paste `find ${out_dir_align} -name *.ReadsPerGene.out.formatted.tsv` | \
    awk 'BEGIN{FS=OFS="\t"} {line=$1; for (i=2;i<NF;i+=4) line=line"\t"$i; print line}' - \
    > ${out_dir_quantification}/star.ReadsPerGene.out.formatted.merged.tsv && printf "***Gene count table merged***\n"

# prepare gene annotation bed file using reference GTF file. note: bed file is 0-based, so chr end +1
cat ${gtf_file} | grep -P '\tgene\t' | \
    awk 'BEGIN{FS="[\t; ]"; OFS="\t"; printf "chromosome\tstart\tend\tensembl_id\tstrand\thgnc_symbol\tgene_biotype\n"} \
              {gsub(/"/,"",$10); gsub(/"/,"",$16); gsub(/"/,"",$22); print $1,$4,$5+1,$10,$7,$16,$22}' > \
              ${out_dir_quantification}/${gtf_file%"gtf"}gene.annot.bed

# count2TPM, this rscript is only used internally in this pipeline
Rscript ${BASEDIR}/r/exon.length.per.gene.R ${gtf_file} ${out_dir_quantification}/${gtf_file%"gtf"}gene.annot.bed ${out_dir_quantification}/star.ReadsPerGene.out.formatted.merged.tsv ${out_dir_quantification}/gene.tpm.tsv && printf "***count to TPM done***\n"


#${BASEDIR}/py/count2TPM.py -c ${out_dir_quantification}/star.ReadsPerGene.out.formatted.merged.tsv -l ${BASEDIR}/data/Mus_musculus.GRCm38.97.gene.withexonlength.bed -o ${out_dir_quantification}/gene.TPM.tsv && printf "***count to TPM done***\n"


############################################BAM2BigWig#############################

