#/usr/bin/env ruby

DEMBYLANEVER = '0.1.0'

require 'congenlib'
require 'optparse'
require 'ostruct'
#-----------------------------------------------------------------------------------------	
class Parser
	def self.parse(options)
		args = OpenStruct.new
		args.infile = '' # Reads to demultiplex
		args.lane = nil # Lane to demultiplex
		args.barcodes = nil # CSV of known barcode combinations
		args.hamming = 0 # Maximum Hamming distance from known barcode
		args.ignore = false # Don't output file of other indexes when using a list of known barcodes
		args.max  = nil # Maximum number of sequences to demultiplex
		args.gzip = false # Gzip output
		opt_parser = OptionParser.new do | opts |
			opts.banner = "Demultiplex by Lane Version " + DEMBYLANEVER
			opts.separator "Michael G. Campana, 2025"
			opts.separator ""
			opts.separator "Usage: demultiplex_by_lane.rb [options]"
			opts.separator ""
			opts.on("-i", "--infile [FILE]", String, "Undetermined reads file to demultiplex") do |infile|
				args.infile = infile
			end
			opts.on("-l", "--lane [VALUE]", Integer, "Specific lane to demultiplex from an undetermined reads file") do |lane|
				args.lane = lane
			end
			opts.on("-b","--barcodes [FILE]", String, "File listing samples with known barcode combinations") do |barcodes|
				args.barcodes = barcodes
			end
			opts.on("-H", "--hamming [VALUE]", Integer, "Maximum number of mismatches from known barcodes to assign read") do |hamming|
				args.hamming = hamming.to_i
			end
			opts.on("-u", "--ignore", "Do not output file of unknown barcodes when using a barcode CSV") do
				args.ignore = true
			end
			opts.on("-m", "--max [VALUE]", Integer, "Maximum number of sequences to demultiplex before quitting") do |max|
				args.max = max
			end
			opts.on("-z", "--gzip", "Gzip output sequence files") do
				args.gzip = true
			end
			# Ideas for additional options:
			# --top X: count the number of instances of barcode and return top X barcodes
			# --tryRC: try the reverse complement of the barcode sequence as this is often a source of error
			opts.on_tail("-h", "--help", "Show help") do
				puts opts
				exit
			end
			opts.on_tail("-v", "--version", "Show version") do
				puts DEMBYLANEVER
				exit
			end
		end
		opt_parser.parse!(options)
		return args
	end
end
#----------------------------------------------------------------------------------------- 
def write_output # Method to write output in the filehash
	for key in $filehash.keys
		next if (key == 'Other' && $options.ignore)
		$options.barcodes.nil? ? prefix = '' : prefix = $samplehash[key] # Add a prefix if the sample name is known
		unless $filehash[key] == '' # Don't open files that are empty
			File.open(prefix+key+$stem, 'a') do |write|
				write << $filehash[key]
			end
			$filehash[key] = ''
		end
	end
end
#-----------------------------------------------------------------------------------------
ARGV[0] ||= '-h'
$options = Parser.parse(ARGV)
$stem = '_' + $options.infile.gsub('.gz','') # Output file stem modifier
$samplehash = {} #Hash associating barcode with sample ID. Ignored if no barcode file.
$filehash = {} #Hash associating barcode with output files
	
unless $options.barcodes.nil? # Read in known barcodes
#Barcode file format is headerless CSV with two columns: sample,index1+index2
	gz_file_open($options.barcodes) do |f2|
		while line = f2.gets
			line_arr = line.strip.split(',')
			$samplehash[line_arr[1]] = line_arr[0] + "_"
			$filehash[line_arr[1]] = '' # Set up output
		end
	end
	$filehash['Other'] = '' # Entry for barcodes that don't match known indexes
	$samplehash['Other'] = '' # Dummy other sample output
end
	
@counter = 0 # Cyclical counter (0..3) to identify sequence headers
@lane = 0
@seqcount = 0 # Number of demultiplexed sequences
gz_file_open($options.infile) do |f1| # Read and demultiplex reads
	while line = f1.gets
		if @counter % 4 == 0
			unless $options.max.nil?
				break if @seqcount == $options.max
			end
			line_arr = line.strip.split(":")
			@lane = line_arr[3].to_i
			unless $options.lane.nil?
				break if @lane > $options.lane # Break if gone past lane of interest
				next if @lane < $options.lane # Skip if before lane of interest
			end
			barcode = line_arr[-1]
			@seqcount += 1
			if $filehash.keys.include?(barcode) # If a barcode/sample file given, all these names already exist in the hash
				$filehash[barcode] << line
			elsif $options.barcodes.nil? # Only add this barcode if extracting EVERY barcode
				$filehash[barcode] = line
			else
				if $options.hamming > 0
					for key in $filehash.keys
						if hamming(key,barcode) <= $options.hamming
							barcode = key
							break
						end
					end
					if $filehash.keys.include?(barcode)
						$filehash[barcode] << line
					else
						barcode = 'Other'
						$filehash[barcode] << line unless $options.ignore # Don't append lines that will never be written or deleted
					end
				else
					barcode = 'Other' # Add unknown barcodes to other file if using barcode/sample list
					$filehash[barcode] << line unless $options.ignore # Don't append lines that will never be written or deleted
				end
			end
		else
			if $options.lane.nil?
				$filehash[barcode] << line
			else
				$filehash[barcode] << line if @lane == $options.lane # Only write info for targeted lane
			end
		end
		@counter += 1
		write_output if @counter % 1000000 == 0 # Write output every million lines
	end
end
write_output # write final output
if $options.gzip
	for key in $filehash.keys
		next if (key == 'Other' && $options.ignore)
		$options.barcodes.nil? ? prefix = '' : prefix = $samplehash[key] # Add a prefix if the sample name is known
		system("gzip #{prefix+key+$stem}")
	end
end