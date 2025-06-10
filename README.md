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
Campana, M.G. 2021. demultiplex v. 0.0.1. Available: https://github.com/campanam/demultiplex.  

### Installation  
This script requires [Ruby](www.ruby-lang.org) and the [congenlib](https://github.com/campanam/congenlib) library. Then download the `demultiplex.rb` script from this repository and place in a convenient location. You can make this program executable by running `chmod +x demultiplex.rb` and putting it in a location within your PATH.  

### Usage:  
`ruby demultiplex.rb <sequence file> [optional barcode CSV]`  

### Notes:  
1. Demultiplexing without a barcode file produces an enormous number of tiny files. I recommend running the script until the correct barcodes are made obvious by their file size and then cancelling and rerunning with a barcode CSV.
2. The Ruby zlib library is not compatible with all compression settings. If the script immediately stops with a tiny result, run the following command to uncompress and recompress the Undetermined reads:
`gunzip -c <input reads> | gzip > <rezipped reads.gz>

