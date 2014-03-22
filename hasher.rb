# This will read a file and mark it with a sha hash


require 'digest/sha1'
require 'fileutils'


$BUFLEN = 1024

class Hasher
	# Constructor
	# filepath = Full filepath
	def initialize(filepath)
			@hashfunc = Digest::SHA2.new(512)
			@hashname = "SHA1"
		  @fullfilename = filepath
	end

	def hashname
		@hashname
	end

	# Compute hash code
	def hashsum
		open(@fullfilename, "r") do |io|
			puts "Reading "+@fullfilename
			counter = 0
			while (!io.eof)
				readBuf = io.readpartial($BUFLEN)
        # putc '.' if ((counter+=1) % 3 == 0)
				@hashfunc.update(readBuf)
			end
		end
		return @hashfunc.hexdigest
	end
end
