# demultiplex_by_lane
### Michael G. Campana, 2021-2025  
### Smithsonian's National Zoo and Conservation Biology Institute

Script to demultiplex reads from Illumina undetermined reads file. Input is an Illumina undetermined reads file (must include the observed index combination in the sequence headers) and optionally a two-column headerless CSV listing the sample name in the first column and the index combination in the second, e.g.:  

samp1,ATGCTGTA+TTTCAACG  
samp2,GGAACCTT+AATTCCGG  
...   
sampX,TGCATGCA+CGTACGTA  

If no barcode file is given, the script will demultiplex by every observed barcode.  

### License  
The software is made available under the Smithsonian Institution [terms of use](https://www.si.edu/termsofuse).  

### Citation  
Campana, M.G. 2025. demultiplex_by_lane v. 0.2.0. Available: https://github.com/campanam/demultiplex.  

### Installation  
This script requires [Ruby](www.ruby-lang.org) and the [congenlib](https://github.com/campanam/congenlib) v. >= 0.3.0 library. Then download the `demultiplex.rb` script from this repository and place in a convenient location. You can make this program executable by running `chmod +x demultiplex.rb` and putting it in a location within your PATH.  

### Usage:  
`ruby demultiplex_by_lane.rb [options]`  

Options:  
`-i`, `--infile [FILE]`: Undetermined reads file to demultiplex (Required).  
`-l`, `--lane [INTEGER]`: Specific lane number to demultiplex from an undetermined reads file (Optional, default is all lanes).  
`-b`,`--barcodes [FILE]`: File listing samples with known barcode combinations (Optional, default is all observed index combinations).  
`-R`, `--RC`: Try reverse complement of barcode sequences (Optional, default is only specified barcodes).  
`-S`, `--switch`: Try switching i5 and i7 barcode sequences (Optional, default is only specified barcodes).  
`-H`, `--hamming [INTEGER]`: Maximum number of mismatches from known barcodes to assign read (Optional, default is 0).  
`-u`, `--ignore`: Do not output file of unknown barcodes when using a barcode CSV (Optional, default is to output unknown barcodes).  
`-m`, `--max [VALUE]`: Maximum number of sequences to demultiplex before quitting (Optional, default is output all reads).  
`-T, --top [VALUE]`: Count the number of instances of the most frequent barcodes (Optional, default is output demultiplexed reads).  
`-z`, `--gzip`: Gzip output sequence files (Optional, default is uncompressed).  
`-h`, `--help`: Show help.  
`-v`, `--version`: Show version.  

### Output:  
By default, reads matching known barcodes will be output in a FASTQ file named "<sample_name>\_<barcode_combo>\_<input_file_name>.fq". Unknown barcodes will be placed in an "Other_<input_file_name>.fq" file. If the `--switch` option is used, reads will be output as "<sample_name>\_<barcode_combo>\_<input_file_name>.fq" for non-switched indexes and "<sample_name>\_S\_<barcode_combo>\_<input_file_name>.fq" for switched indexes.  If the `--RC` option is used, reads with known barcodes will be output as "<sample_name>\_<directional_prefix>\_<barcode_combo>\_<input_file_name>.fq" (F for forward, R for reverse-complemented). If the `--switch` option is used with the `--RC` option, reads will be output as "<sample_name>\_<directional_prefix>\_<barcode_combo>\_<input_file_name>.fq" for non-switched indexes and "<sample_name>\_<directional_prefix>S\_<barcode_combo>\_<input_file_name>.fq" for switched indexes.  

### Notes:  
1. Demultiplexing without a barcode file produces an enormous number of tiny files. I recommend using the `--max` and `--top` options to run a subset of reads and identify the most frequent combinations.  
2. The Ruby zlib library is not compatible with all compression settings. If the script immediately stops with a tiny result, run the following command to uncompress and recompress the Undetermined reads:
`gunzip -c <input reads> | gzip > <rezipped reads.gz>`  

