#!usr/bin/Rscript


# This script is used to compute gene TPM by using gene count table and reference GTF file

###############################functions, argments###############################

# union exons to a set of non overlapping exons, calculate their lengths and sum then
get.exon.len.by.gene <- function (x) {
  # x: GenomicRanges object
  merged.exon <- GenomicRanges::reduce(x)
  vec.exon.len <- BiocGenerics::width(merged.exon)
  exon.len.total <- sum(vec.exon.len)
  return (exon.len.total)
}

# compute TPM according to reads counts and exon length of genes
count2TPM <- function (vec_count, vec_length){
  # vec_count: gene count vector, vec_length: gene exon total length vector
  a <- vec_count / vec_length
  tpm <- a / sum(a) * 1e6
  return(tpm)
}

# parse argument
options <- commandArgs(trailingOnly = TRUE)
gtf.file <- options[1]    # the first position argument is reference GTF file
annot.file <- options[2]    # the second position argument is gene annoattion file extracting from GTF file by shell cmd in pipeline
count.file<- options[3]    # the third position argument is gene counts file
out.file.path <- options[4]    # the fourth position argument is the path of output TPM file

###############################prepare exon length per gene###############################

suppressWarnings(suppressMessages(library("GenomicFeatures")))

print("***Compute total exon length per gene***")
# import GTF file: return TxDb object
txdb <- makeTxDbFromGFF(gtf.file, format="gtf")

# group exons by gene_id: return GRangesList object
exons.per.gene <- exonsBy(x=txdb, by="gene")

# compute total exon length for each gene
list.exon.len.per.gene <- lapply(X=exons.per.gene, FUN=get.exon.len.by.gene)

# list to vector to dataframe
df_len <- as.data.frame(unlist(list.exon.len.per.gene))
df_len$ensembl_id <- rownames(df_len)
df_len <- df_len[,c(2,1)]
colnames(df_len)[2] <- "exon_length"
print("done")


##########################################count2TPM#######################################

print("***Computing TPM***")
# read and sort (by gene ID) annot and count file
df_annot <- read.table(file = annot.file, sep='\t', header = T)
df_annot <- df_annot[order(df_annot$ensembl_id), ]

df_count <- read.table(file = count.file, sep = '\t', header = T)
df_count <- df_count[order(df_count$ensembl_id), ]

# merge annotation table, exon length per gene table and count table
df <- cbind(df_annot, df_len, df_count)
df <- df[, -c(8,10)]

# compute TPM
df.tpm <- round(sapply(df[,c(9:dim(df)[2])], function(vec_count) {count2TPM(vec_count, vec_length=df$exon_length)}), 3)
df <- cbind(df[,1:8], df.tpm)

write.table(df, out.file.path, quote = F, sep = '\t', row.names = F)

