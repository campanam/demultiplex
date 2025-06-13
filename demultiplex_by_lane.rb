#/usr/bin/env ruby

DEMBYLANEVER = '0.2.0'

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
		args.rc = false # Try RC of index sequences
		args.switch = false # Try switching i5 and i7
		args.hamming = 0 # Maximum Hamming distance from known barcode
		args.ignore = false # Don't output file of other indexes when using a list of known barcodes
		args.max  = nil # Maximum number of sequences to demultiplex
		args.top = nil # Return most frequent barcodes
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
			opts.on("-R", "--RC", "Try reverse complement of barcode sequences") do |rc|
				args.rc = true
			end
			opts.on("-S", "--switch", "Try switching i5 and i7 barcode sequences") do |rc|
				args.switch = true
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
			opts.on("-T", "--top [VALUE]", Integer, "Count the number of instances of the most frequent barcodes") do |top|
				args.top = top
			end
			opts.on("-z", "--gzip", "Gzip output sequence files") do
				args.gzip = true
			end
			# Ideas for additional options:
			# --top X: count the number of instances of barcode and return top X barcodes
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
def output_barcodes # Method to output top X barcodes
	puts "KnownSample\tBarcode\tCount"
	toparr = $filehash.sort_by { |key, value| value }
	toparr.reverse!
	$options.top = toparr.size if $options.top > toparr.size
	for i in 0 ... $options.top
		$options.barcodes.nil? ? sample = '' : sample = $samplehash[toparr[i][0]] # Add a sample if the sample name is known
		puts sample + "\t" + toparr[i][0] + "\t" + toparr[i][1].to_s
	end
end
#-----------------------------------------------------------------------------------------
ARGV[0] ||= '-h'
$options = Parser.parse(ARGV)
$stem = '_' + $options.infile.gsub('.gz','') # Output file stem modifier
$samplehash = {} #Hash associating barcode with sample ID. Ignored if no barcode file.
$filehash = {} #Hash associating barcode with output files

build_rc_hash if $options.rc
	
unless $options.barcodes.nil? # Read in known barcodes
#Barcode file format is headerless CSV with two columns: sample,index1+index2
	gz_file_open($options.barcodes) do |f2|
		while line = f2.gets
			line_arr = line.strip.split(',')
			if $options.rc
				index_arr = line_arr[1].split('+')
				if index_arr.size == 1 # Single-indexed run
					$samplehash[line_arr[1]] = line_arr[0] + "_F_"
					$samplehash[rc(line_arr[1])] = line_arr[0] + "_R_"
					$options.top.nil? ? $filehash[line_arr[1]] = '' : $filehash[line_arr[1]] = 0 # Set up output
					$options.top.nil? ? $filehash[rc(line_arr[1])] = '' :$filehash[rc(line_arr[1])] = 0 # Set up output
					if $options.switch
						STDERR.puts "Barcodes are single-indexed. Turning off switch option."
						STDERR.puts "Error found here in barcode CSV: " + line
						$options.switch = false
					end
				else
					# Unmodified indexes
					$samplehash[line_arr[1]] = line_arr[0] + "_FF_"
					$options.top.nil? ? $filehash[line_arr[1]] = '' : $filehash[line_arr[1]] = 0 # Set up output
					index1 = index_arr[0]
					index2 = index_arr[1]
					rc_index1 = rc(index1)
					rc_index2 = rc(index2)
					# RC both indexes
					both_rc = rc_index1 + "+" + rc_index2
					$samplehash[both_rc] = line_arr[0] + "_RR_"
					$options.top.nil? ? $filehash[both_rc] = '' : $filehash[both_rc] = 0 # Set up output
					# RC index1
					for_rc = rc_index1 + "+" + index2
					$samplehash[for_rc] = line_arr[0] + "_RF_"
					$options.top.nil? ? $filehash[for_rc] = '' : $filehash[for_rc] = 0 # Set up output
					# RC index2
					rev_rc = index1 + "+" + rc_index1
					$samplehash[rev_rc] = line_arr[0] + "_FR_"
					$options.top.nil? ? $filehash[rev_rc] = '' : $filehash[rev_rc] = 0 # Set up output
					if $options.switch
						# Switch original indexes
						switch = index_arr[1] + '+' + index_arr[0]
						$samplehash[switch] = line_arr[0] + "_FFS_"
						$options.top.nil? ? $filehash[switch] = '': $filehash[switch] = 0
						#RC both and switch
						both_rcS = rc_index2 + "+" + rc_index1
						$samplehash[both_rcS] = line_arr[0] + "_RRS_"
						$options.top.nil? ? $filehash[both_rcS] = '' : $filehash[both_rcS] = 0 # Set up output
						# RC index1 and switch
						for_rcS = rc_index2 + "+" + index1
						$samplehash[for_rcS] = line_arr[0] + "_RFS_"
						$options.top.nil? ? $filehash[for_rcS] = '' : $filehash[for_rcS] = 0 # Set up output
						# RC index2 and switch
						rev_rcS = index2 + "+" + rc_index1
						$samplehash[rev_rcS] = line_arr[0] + "_FRS_"
						$options.top.nil? ? $filehash[rev_rcS] = '' : $filehash[rev_rcS] = 0 # Set up output
					end
				end
			else				
				$samplehash[line_arr[1]] = line_arr[0] + "_"
				$options.top.nil? ? $filehash[line_arr[1]] = '' : $filehash[line_arr[1]] = 0 # Set up output
				if $options.switch
					index_arr = line_arr[1].split('+')
					if index_arr.size == 1
						STDERR.puts "Barcodes are single-indexed. Turning off switch option."
						STDERR.puts "Error found here in barcode CSV: " + line
						$options.switch = false
					else
						switch = index_arr[1] + '+' + index_arr[0]
						$samplehash[switch] = line_arr[0] + "_S_"
						$options.top.nil? ? $filehash[switch] = '' : $filehash[switch] = 0
					end
				end	
			end
		end
	end
	$options.top.nil? ? $filehash['Other'] = '' : $filehash['Other'] = 0 # Entry for barcodes that don't match known indexes
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
				$options.top.nil? ? $filehash[barcode] << line : $filehash[barcode] += 1
			elsif $options.barcodes.nil? # Only add this barcode if extracting EVERY barcode
				$options.top.nil? ? $filehash[barcode] = line : $filehash[barcode] = 1
			else
				if $options.hamming > 0
					for key in $filehash.keys
						if hamming(key,barcode) <= $options.hamming
							barcode = key
							break
						end
					end
					if $filehash.keys.include?(barcode)
						$options.top.nil? ? $filehash[barcode] << line : $filehash[barcode] += 1
					else
						barcode = 'Other'
						if $options.top.nil?
							$filehash[barcode] << line unless $options.ignore # Don't append lines that will never be written or deleted
						else
							$filehash[barcode] += 1
						end
					end
				else
					barcode = 'Other' # Add unknown barcodes to other file if using barcode/sample list
					if $options.top.nil?
						$filehash[barcode] << line unless $options.ignore # Don't append lines that will never be written or deleted
					else
						$filehash[barcode] += 1
					end
				end
			end
		elsif !$options.top.nil?
			@counter += 1
			next
		else
			if $options.lane.nil?
				$filehash[barcode] << line
			else
				$filehash[barcode] << line if @lane == $options.lane # Only write info for targeted lane
			end
		end
		@counter += 1
		write_output if @counter % 1000000 == 0 # Write output every million lines.
	end
end
if !$options.top.nil?
	output_barcodes # Output most frequent barcodes
else
	write_output # write final output
end
if $options.gzip
	for key in $filehash.keys
		next if (key == 'Other' && $options.ignore)
		$options.barcodes.nil? ? prefix = '' : prefix = $samplehash[key] # Add a prefix if the sample name is known
		system("gzip #{prefix+key+$stem}")
	end
end
