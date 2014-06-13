require 'NtUtil'

$:.push("#{File.dirname(__FILE__)}/../../../util")
require 'binary_struct'
require 'miq-unicode'

require 'NtfsAttribStandardInformation'

module NTFS
		
  # 
  # FILE_NAME_ATTR - Attribute: Filename (0x30)
  # 
  # NOTE: Always resident.
  # NOTE: All fields, except the parent_directory, are only updated when the
  #   filename is changed. Until then, they just become out of sync with
  #   reality and the more up to date values are present in the standard
  #   information attribute.
  # NOTE: There is conflicting information about the meaning of each of the time
  #   fields but the meaning as defined below has been verified to be
  #   correct by practical experimentation on Windows NT4 SP6a and is hence
  #   assumed to be the one and only correct interpretation.
  # 		
		
	# The $FILE_NAME attribute.
	ATTRIB_FILE_NAME = BinaryStruct.new([
		'Q',  'ref_to_parent_dir',  # Directory this filename is referenced from
		'Q',  'time_created',       # Time file was created
		'Q',  'time_altered',       # Time the data attribute was last modified
		'Q',  'time_mft_changed',   # Time this mft record    was last modified
		'Q',  'time_read',          # Last time this mft record was accessed
		'Q',  'allocated_size',     # Byte size of on-disk allocated space for the data attribute.  
		                            # So for normal $DATA, this is the allocated_size from the unnamed
		                            # $DATA attribute and for compressed and/or sparse $DATA, this is 
		                            # the compressed_size from the unnamed $DATA attribute.  
		                            # NOTE: This is a multiple of the cluster size.
		'Q',  'data_size',          # Byte size of actual data in data attribute
		'L',  'flags',              # Flags describing the file
		'L',  'reparse_point_tag',  # Type of reparse point, present only in reparse points and only if there are no EAs
		'C1', 'name_length',        # Length of file name in (Unicode) characters
		'C1', 'namespace',          # Namespace of the file name
	])
	# File name (in UNICODE) is appended to the previous structure.
  SIZEOF_ATTRIB_FILE_NAME = ATTRIB_FILE_NAME.size

	class FileName
		
		attr_reader :name, :namespace, :length, :permissions, :refParent
		
		NS_POSIX  = 0
		NS_WIN32  = 1
		NS_DOS    = 2
		NS_DOSWIN = 3

    UNNAMED = '[unnamed]'.AsciiToUtf8.freeze

		def initialize(buf)
			raise "MIQ(NTFS::FileName.initialize) Nil buffer" if buf.nil?
			buf          = buf.read(buf.length) if buf.kind_of?(DataRun)
			@afn         = ATTRIB_FILE_NAME.decode(buf)
			buf          = buf[SIZEOF_ATTRIB_FILE_NAME, buf.size]
	    
			# Set accessor data.
			@permissions = @afn['flags']
			@length      = @afn['data_size']
			@namespace   = @afn['namespace']
			@refParent   = NtUtil.MkRef(@afn['ref_to_parent_dir'])
	    
			# If there's a name get it.
			len          = @afn['name_length'] * 2
			@name        = buf[0, len].UnicodeToUtf8 if len > 0
			
			# If name is nil use NT standard unnamed.
			@name      ||= UNNAMED.dup
		end
		
		def to_s
			@name
		end
		
    def mTime
      @mTime ||= NtUtil.NtToRubyTime(@afn['time_altered'])
    end

    def aTime
			@aTime ||= NtUtil.NtToRubyTime(@afn['time_read'])
    end

    def cTime
			@cTime ||= NtUtil.NtToRubyTime(@afn['time_created'])
    end

		# Returns nil if not directory.
		def isDir?
			NtUtil.gotBit?(@permissions, StandardInformation.FP_DIRECTORY)
		end
	  
		def dump
			out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
			out << "  Parent dir : seq #{@refParent[0]}, entry #{@refParent[1]}\n"
			out << "  Created    : #{@cTime}\n"
			out << "  Modified   : #{@mTime}\n"
			out << "  MFT changed: #{NtUtil.NtToRubyTime(@afn['time_mft_changed'])}\n"
			out << "  Accessed   : #{@aTime}\n"
			out << "  Allocated  : #{@afn['allocated_size']}\n"
			out << "  Real size  : #{@length}\n"
			out << "  Flags      : 0x#{'%08x' % @flags}\n"
			out << "  Reparse    : #{@afn['reparse_point_tag']}\n"
			out << "  Name length: #{@afn['name_length']}\n"
			out << "  Namespace  : #{@namespace}\n"
			out << "  Name       : #{@name}\n"
			out << "---\n"
		end
	end
end # module NTFS
