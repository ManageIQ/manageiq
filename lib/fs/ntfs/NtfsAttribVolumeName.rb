$:.push("#{File.dirname(__FILE__)}/../../../util")

require 'binary_struct'
require 'miq-unicode'

module NTFS
		
	# 
  # VOLUME_NAME - Attribute: Volume name (0x60).
  # 
  # NOTE: Always resident.
  # NOTE: Present only in FILE_Volume.
  # 
	# Data of this class is not structured.
  #	
  
	class VolumeName
	  
		attr_reader :name
	  
		def initialize(buf)
			buf   = buf.read(buf.length) if buf.kind_of?(DataRun)
			@name = buf.UnicodeToUtf8
		end
	  
		def to_s
			@name
		end
	  
		def dump
			out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n  "
			out << @name
			out << "---\n"
		end
	end
end # module NTFS
