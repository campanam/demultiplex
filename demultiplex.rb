#/usr/bin/env ruby

# demultiplex version 0.0.1
# Michael G. Campana, 2021
# This is a preliminary version of the demultiplex_by_lane.rb script.  

require 'congenlib'

@samplehash = {} #Hash associating barocde with sample ID. Ignored if no barcode file.
@filehash = {} #Hash associating barcode with output files
@counter = 0 # Cyclical counter (0..3) to identify sequence headers
@stem = '_' + ARGV[0].gsub('.gz','') # Output file stem modifier

def write_output # Method to write output in the filehash
	for key in @filehash.keys
		ARGV[1].nil? ? prefix = '' : prefix = @samplehash[key] # Add a prefix if the sample name is known
		unless @filehash[key] == '' # Don't open files that are empty
			File.open(prefix+key+@stem, 'a') do |write|
				write << @filehash[key]
			end
			@filehash[key] = ''
		end
	end
end

unless ARGV[1].nil? # Read in known barcodes
	#Barcode file format is headerless CSV with two columns: sample,index1+index2
	gz_file_open(ARGV[1]) do |f2|
		while line = f2.gets
			line_arr = line.strip.split(',')
			@samplehash[line_arr[1]] = line_arr[0] + "_"
			@filehash[line_arr[1]] = '' # Set up output
		end
	end
	@filehash['Other'] = '' # Entry for barcodes that don't match known indexes
	@samplehash['Other'] = '' # Dummy other sample output
end

gz_file_open(ARGV[0]) do |f1|
	while line = f1.gets
		if @counter % 4 == 0
			barcode = line.strip.split(":")[-1]
			if @filehash.keys.include?(barcode) # If a barcode/sample file given, all these names already exist in the hash
				@filehash[barcode] << line
			elsif ARGV[1].nil? # Only add this barcode if extracting EVERY barcode
				@filehash[barcode] = line
			else
				barcode = 'Other' # Add unknown barcodes to other file if using barcode/sample list
				@filehash[barcode] << line
			end
		else
			@filehash[barcode] << line
		end
		@counter += 1
		write_output if @counter % 1000000 == 0 # Write output every million lines
	end
end
write_output # write final output

# Ideas for additional options:
# --top X: count the number of instances of barcode and return top X barcodes
# --tryRC: try the reverse complement of the barcode sequence as this is often a source of error
