# This will read a file and mark it with a sha hash

require 'digest/sha1'
require 'fileutils'

$BUFLEN = 1024

class Hasher

  attr_accessor :hashname

	def initialize(filepath)
    @hashfunc = Digest::SHA2.new(512)
    @hashname = "SHA1"
    @fullfilename = filepath
	end

	def hashsum
		open(@fullfilename, "r") do |io|
			puts "Reading "+@fullfilename
			while (!io.eof)
				readBuf = io.readpartial($BUFLEN)
				@hashfunc.update(readBuf)
			end
		end

		return @hashfunc.hexdigest
	end
end
