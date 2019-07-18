#!/usr/bin/bash


# 帮助文档
helpdoc(){
    cat <<EOF
Description:

    This shellscript is used to download fastq file from SRA database
    using fasterq-dump (next-generation fastq-dump). You should have bgzip
    to perform comporess after download. bgzip are part of samtools.

Usage:

    $0 -f <SRA run table> -o <output directory> -@ <threads>

Option:

    -f    SRA run table file, download from SRA database (Required)
    -o    output directory, default value is the current directory
    -@    thread to use, default 8
EOF
}


# 若无指定任何参数则输出帮助文档
if [ $# = 0 ]
then
    helpdoc
    exit 1
fi


# 传参
out_dir="./"
thread=8
while getopts "hf:o:@:" opt
do
    case $opt in
        h)
            helpdoc
            exit 0
            ;;
        f)
            sra_run_table=$OPTARG
            if [ ! -f ${sra_run_table} ]
            then
                echo "No such file: ${sra_run_table}"
                helpdoc
                exit 1
            fi
            ;;
        o)
            out_dir=${OPTARG%"/"}
            if [ ! -d ${out_dir} ]
            then
                echo "No such directory: ${out_dir}"
                helpdoc
                exit 1
            fi
            ;;
        @)
            thread=$OPTARG
            if ! [[ "${thread}" =~ ^[0-9]+$ ]]; then
                echo "Thread should be integers only"
                helpdoc
                exit 1
            fi
            ;;
        ?)
            echo "Unknown option: $opt"
            helpdoc
            exit 1
            ;;
    esac
done


accesion_list=`awk 'BEGIN{FS="\t"} NR==1{for(i=1;i<=NF;i++) if($i=="Run") colnum=i} NR>1{print $colnum}' ${sra_run_table}`
count=1
total=`echo ${accesion_list} | wc -w`


# configure sra-toolkit to change the default sra.chache file position 
mkdir -p ~/.ncbi
echo "/repository/user/main/public/root = \"${out_dir}\"" > $HOME/.ncbi/user-settings.mkfg

# Run fasterq-dump, downloading fastq file
for i in ${accesion_list} 
do
    echo "Downloading: ${i} (${count}/${total})"
    # use fasterq-dump, not fastq-dump
    time fasterq-dump ${i} -O ${out_dir} -t ${out_dir} -e ${thread}
    count=$[ ${count} + 1 ]
done
echo "All files downloaded"

# compress
printf "***Compressing***\n"
find ${out_dir} -name "*.fastq" | xargs -n1 bgzip -@ ${thread} 
printf "***Compress done***\n"

printf "***Removing tmp file in: \'${out_dir}/sra\'***\n"
rm -rf ${out_dir}/sra

echo "Done"



