<p align="center">
  <img width="250" height="250" src="./img/logo2.png">
</p>
 
***

# omics-pipeline: pipelines for various omics analysis 

## Usage:
```
git clone https://github.com/CadenZhao/omics-pipeline.git
cd omics-pipeline/omxpipeline

# use -h flag to check the usage
./SRAdownload-pipeline.py -h
./bulkRNA-pipeline.sh -h
<path to pipeline> -h
```

## Pipeline description
### 1. SRAdownload-pipeline.sh
easily download fastq file from SRA database 
requirements: 
1. sra-toolkit (should include fasterq-dump) 
2. SraRunTable.txt (downloaded from SRA database) 

### 2. bulkRNA-pipeline.sh
QC, alignment, gene count, gene TPM, BAM to BigWig
#### Requirements:
gMode:
trimmomatic  
fastqc  
multiqc  
STAR  
samtools  
R (with GenomicFeatures package) 

tMode:
trimmomatic  
fastqc  
multiqc  
salmon

### 3. scRNA-pipeline.sh
working on...

### 4. ChIPseq-pipeline.sh
working on...

### 5. WGS-pipeline.sh
working on...

