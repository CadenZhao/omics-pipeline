<p align="center">
  <img width="250" height="250" src="./img/logo2.png">
</p>
 
***

# omics-pipeline: pipelines for various omics analysis 

## Usage:
```
git clone https://github.com/CadenZhao/omics-pipeline.git
cd omics-pipeline/pipeline
chmod 755 ./*

# use -h flag to check the usage
./SRAdownload-pipeline.sh -h
./bulkRNA-pipeline.sh -h
./blabla-pipeline.sh -h
```

## Pipeline description
### 1. SRAdownload-pipeline.sh
download fastq file directly
requirements: sra-toolkit, SraRunTable.txt downloaded from SRA database

### 2. bulkRNA-pipeline.sh
QC, alignment, gene count, gene TPM, BAM to BigWig
#### Requirements:
trimmomatic  
fastqc  
multiqc  
STAR  
samtools  
python (with pandas library)  
R (with blabla library)  

### 3. scRNA-pipeline.sh
working on...

### 4. ChIPseq-pipeline.sh
working on...

### 5. WGS-pipeline.sh
working on...

