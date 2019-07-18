#!/usr/bin/env python
# encoding: utf-8
import argparse
import pandas as pd

def count2TPM(sr_counts, sr_gene_exon_l):
    """compute gene TPM from gene counts
    sr_counts: pandas.Series, counts vector for all genes of one sample
    sr_gene_exon_l: pandas.Series, total exon length vector for all genes 
    """
    a = sr_counts / sr_gene_exon_l
    tpm = a / a.sum() * 1e6
    return tpm

def parseArg():
    """Recieve parameters from commander line
    """
    parser = argparse.ArgumentParser(description='gene count to gene TPM')
    parser.add_argument("-c", "--countsFile", required=True, help="gene reads count file")
    parser.add_argument("-l", "--lengthFile", required=True, help="file containing gene total exon length")
    parser.add_argument("-o", "--outFile", default='./out.tpm.tsv', help='path of output file')
    argments = parser.parse_args()
    return argments 

def main():
    # parse arguments
    args = parseArg()
    counts_file, length_file, out_file = args.countsFile, args.lengthFile, args.outFile

    # read
    df_count = pd.read_csv(counts_file, sep='\t')
    df_length = pd.read_csv(length_file, sep='\t')

    # merge
    df = pd.merge(df_length, df_count, on='ensembl_id', how='outer')

    # count2TPM
    df_tpm = df.iloc[:,8:].transform(lambda col: count2TPM(sr_counts=col, sr_gene_exon_l=df['total_exon_length'])).round(4)

    # merge again
    df_tpm = pd.concat([df.loc[:,'chromosome':'total_exon_length'], df_tpm], axis=1, ignore_index=True)
    df_tpm.columns = df.columns

    # write
    df_tpm.to_csv(out_file, sep='\t', index=False)

if __name__ == '__main__':
    main()
