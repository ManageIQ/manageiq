require 'platform'

$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'
require 'miq-unicode'

module Iso9660
	
	# SUSP extensions are present if the first two characters of the SUA of
	# the first directory entry are "SP". After SUSP is identified, if the
	# first two characters of any directory entry's SUA are "RR" a Rock Ridge
	# extension is active for that entry. The particular extension is
	# identified by the two characters after the next two bytes following "RR".
	
	# NOTE: This implementation is sufficient for Rock Ridge extensions. It will
	# not identify or process any other System Use Sharing Protocol extensions.
	# In particular, SUSP CE (continuation area) records are not processed. This
	# is where the "RR" extension is defined. This implementation uses the
	# assumed definition RR_HEADER.
	
	RR_SIGNATURE = "RR"
	RR_HEADER = BinaryStruct.new([
		'a2',	'signature',	# RR if Rock Ridge.
		'C',	'unused1',		# ? always seems to be 5.
		'C',	'unused2',		# ? always seems to be 1 (version?).
		'C',	'unused3'			# ? 0x81
	])
	RR_HEADER_SIZE = 5
	
	# These types are not used, but we want to know if they pop up.
	RR_PN_SIGNATURE = "PN"
	RR_CL_SIGNATURE = "CL"
	RR_PL_SIGNATURE = "PL"
	RR_RE_SIGNATURE = "RE"
	RR_TF_SIGNATURE = "TF"
	
	# POSIX file attributes. See POSIX 5.6.1.
	RR_PX_SIGNATURE = "PX"
	RR_PX = BinaryStruct.new([
		'L',	'modeLE',		# file mode (used to identify a link).
		'L',	'modeBE',
		'L',	'linksLE',	# Num links (st_nlink).
		'L',	'linksBE',
		'L',	'userLE',		# User ID.
		'L',	'userBE',
		'L',	'groupLE',	# Group ID.
		'L',	'groupBE'
		#'L',	'serialLE',	# File serial number.
		#'L',	'serialBE'
	])
	# NOTE: IEEE P1282 specifies that file serial number is included, but
	# real data shows this number is absent. Likewise, the spec says the
	# struct length is 44 bytes, where real data shows a length of 36 bytes.
	# It's also worth noting that the real data shows a structure version
	# of 1, so there is definitely disagreement betweeen theory (IEEE P1282)
	# and reality (the Open Solaris developer edition distro iso).
	
	# File mode bits.
	RR_EXT_SL_FM_SOCK	= 0xc000
	RR_EXT_SL_FM_LINK	= 0xa000
	RR_EXT_SL_FM_FILE	= 0x8000
	RR_EXT_SL_FM_BLOK	= 0x6000
	RR_EXT_SL_FM_CHAR	= 0x2000
	RR_EXT_SL_FM_DIR	=	0x4000
	RR_EXT_SL_FM_FIFO	= 0x1000
		
	class PosixAttributes
		
		attr_reader :flags
		
		def initialize(data, suff)
			@flags = 0
			@suff = suff
			@px = RR_PX.decode(data)
		end
		
		def mode
			@px["mode#{@suff}"]
		end
		
		def nlinks
			@px["links#{@suff}"]
		end
		
		def user
			@px["user#{@suff}"]
		end
		
		def group
			@px["group#{@suff}"]
		end
		
		def isFile?
			self.mode & RR_EXT_SL_FM_FILE != 0
		end
		
		def isDir?
			self.mode & RR_EXT_SL_FM_DIR != 0
		end
		
		def isSymLink?
			self.mode & RR_EXT_SL_FM_LINK != 0
		end
	end #class PosixAttributes
	
	# Symbolic link.
	RR_SL_SIGNATURE = "SL"
	RR_SL = BinaryStruct.new([
		'C',	'flags',	# See RR_EXT_SLF_ below.
		'a*',	'components'
	])
	
	# Symbolic link flags.
	RR_EXT_SLF_CONTINUE	= 0x01	# Link continues in the next SL entry.
	
	# A symbolic link component record.
	RR_SL_COMPONENT = BinaryStruct.new([
		'C',	'flags',	# See RR_EXT_SLCOMPF_ below.
		'C',	'length',	# Length of content in bytes.
		'a*',	'content'
	])
	
	RR_EXT_SLCOMPF_CONTINUE		= 0x01	# Component continues in the next component record.
	RR_EXT_SLCOMPF_CURRENT		= 0x02	# Component refers to the current directory.
	RR_EXT_SLCOMPF_PARENT			= 0x04	# Component refers to the parent directory.
	RR_EXT_SLCOMPF_ROOT				= 0x08	# Component refers to the root directory.
	RR_EXT_SLCOMPF_RESERVED1	= 0x10	# See below.
	RR_EXT_CLCOMPF_RESERVED2	= 0x20	# See below.
	# RESERVED1: Historically, this component has referred to the directory on
	# which the current CD-ROM is mounted.
	# Reserved2: Historically, this component has contained the network node
	# name of the current system as defined in the uname structure of POSIX 4.4.1.2
	
	class SymbolicLink
		
		attr_reader :flags
		attr_accessor :linkData
		
		def initialize(data, suff)
			sl = RR_SL.decode(data)
			
			# Reader data.
			@flags = sl['flags']
			@linkData = assembleComponents(sl['components'])
		end
		
		def assembleComponents(data)
			out = ""; offset = 0
			loop do
				comp = RR_SL_COMPONENT.decode(data[offset..-1])
				
				# Check for referential flags.
				out += "./" if comp['flags'] & RR_EXT_SLCOMPF_CURRENT != 0
				out += "../" if comp['flags'] & RR_EXT_SLCOMPF_PARENT != 0
				out += "/" if comp['flags'] & RR_EXT_SLCOMPF_ROOT != 0
				
				# Advance offset, append content (if any) & check for done.
				#puts "Component content:"
        #comp['content'][0, comp['length']].hex_dump(:obj => STDOUT, :meth => :puts, :newline => false)
        #puts "\n\n"
				offset += comp['length'] + 2 #compensate for first two bytes of component.
				next if comp['length'] == 0
				out = File.join(out, comp['content'][0, comp['length']])
				#break if comp['flags'] & RR_EXT_SLCOMPF_CONTINUE == 0
				# Analysis of real data shows the condition is offset >= data len.
				break if offset >= data.length
			end
			#puts "Total content:"
      #out.hex_dump(:obj => STDOUT, :meth => :puts, :newline => false)
      #puts "\n\n"
			return out
		end
	end #class SymbolicLink
	
	# Alternate name.
	RR_NM_SIGNATURE = "NM"
	RR_NM = BinaryStruct.new([
		'C',	'flags',	# See RR_EXT_NMF_ below.
		'a*',	'content'
	])
	
	# NOTE: These flag bits are mutually exclusive.
	RR_EXT_NMF_CONTINUE		= 0x01	# Name continues in the next NM entry.
	RR_EXT_NMF_CURRENT		= 0x02	# Name refers to the current directory.
	RR_EXT_NMF_PARENT			= 0x04	# Name refers to the parent directory.
	RR_EXT_NMF_RESERVED1	= 0x08	# Reserved - 0.
	RR_EXT_NMF_RESERVED2	= 0x10	# Reserved - 0.
	RR_EXT_NMF_RESERVED3	= 0x20	# Implementation specific.
	# NOTE: IEEE-P1282 lists the following note about RESERVED3:
	# Historically, this component has contained the network node name of
	# the current system as defined in the uname structure of POSIX 4.4.1.2
	
	class AlternateName
		
		attr_reader :flags
		attr_accessor :name
		
		def initialize(data, suff)
			an = RR_NM.decode(data)
			
			# Check for referential flags.
			@name = ""
			@name += "./" if an['flags'] & RR_EXT_NMF_CURRENT != 0
			@name += "../" if an['flags'] & RR_EXT_NMF_PARENT != 0
			raise "RR extension NM: RESERVED3 flag is set." if an['flags'] & RR_EXT_NMF_RESERVED3 != 0
			
			# Reader data.
			@flags = an['flags']
			@name += an['content']
		end
	end #class AlternateName
	
	# Sparse File.
	RR_SF_SIGNATURE = "SF"
	RR_SF = BinaryStruct.new([
		'L',	'size_hiLE',
		'L',	'size_hiBE',
		'L',	'size_loLE',
		'L',	'size_loBE',
		'C',	'table_depth',
	])
	
	# Um, sparse file is pretty complicated so I'm just going to get the
	# first three going and then worry about this.
	
	class SparseFile
		
		attr_reader :length, :fileData, :flags
		
		def initialize(data, suff)
			@sf = RR_SF.decode(data)
			@flags = 0
			@suff = suff
			raise "Sparse file."
		end
		
		def length
			(@sf["size_hi#{@suff}"] << 32) + @sf["size_lo#{@suff}"]
		end
		
	end #class SparseFile
	
	# Common to all RR extensions.
	RR_EXT_HEADER = BinaryStruct.new([
		'a2',	'signature',	# Extension type.
		'C',	'length',			# length in bytes.
		'C',	'version'			# Entry version, always 1.
	])
	RR_EXT_HEADER_SIZE = 4
	
	class Extension
		
		attr_reader :length, :ext
		
		def initialize(data, suff)
			# Get extension header, length & data.
			@header = RR_EXT_HEADER.decode(data)
			@length = @header['length']
			data = data[RR_EXT_HEADER_SIZE, @length - RR_EXT_HEADER_SIZE]
			#puts "Extension data (from Extension):"
      #data.hex_dump(:obj => STDOUT, :meth => :puts, :newline => false)
      #puts "\n\n"

			# Delegate to extension.
			@ext = case @header['signature']
				when RR_PX_SIGNATURE then PosixAttributes.new(data, suff)
				when RR_PN_SIGNATURE then warnAbout(RR_PN_SIGNATURE, data)
				when RR_SL_SIGNATURE then SymbolicLink.new(data, suff)
				when RR_NM_SIGNATURE then AlternateName.new(data, suff)
				when RR_CL_SIGNATURE then warnAbout(RR_CL_SIGNATURE, data)
				when RR_PL_SIGNATURE then warnAbout(RR_PL_SIGNATURE, data)
				when RR_RE_SIGNATURE then warnAbout(RR_RE_SIGNATURE, data)
				when RR_TF_SIGNATURE then warnAbout(RR_TF_SIGNATURE, data)
				when RR_SF_SIGNATURE then SparseFile.new(data, suff)
			end
		end
		
		def warnAbout(ext, data)
      if $log
        $log.debug("RR extension #{ext} found, not processed. Data is:")
        data.hex_dump(:obj => $log, :meth => :debug, :newline => false)
      end
			return nil
		end
	end #class Extension
	
	class RockRidge
		
		SUSP_SIZE = 7
		CONTINUE = 1
		
		attr_reader :extensions
		
		def initialize(de, suff)
			raise "No DirectoryEntry specified." if de.nil?
			raise "The specified DirectoryEntry has no System Use Area." if de.sua.nil?
			
			# Root directories need to skip SUSP header.
			offset = de.name == "." ? SUSP_SIZE : 0
			
			# Get the RR header from the DirectoryEntry & verify.
			@header = RR_HEADER.decode(de.sua[offset..-1])
			raise "This is not a Rock Ridge extension record" if @header['signature'] != RR_SIGNATURE
			
			# Loop through extensions.
			offset += RR_HEADER_SIZE
			@extensions = Array.new
			loop do
				#puts "Extension data:
        #de.sua[offset..-1].hex_dump(:obj => STDOUT, :meth => :puts, :newline => false)
        #puts "\n\n"
				ext = Extension.new(de.sua[offset..-1], suff)
				@extensions << ext
				offset += ext.length
				break if offset >= de.sua.length
			end
			
			# Handle continuations.
			0.upto(@extensions.size - 1) do |idx|
				obj = @extensions[idx]
				next if obj.nil?
				
				# TODO Simplify this - the meat of all extensions is .data
				if obj.flags & CONTINUE
					if obj.kind_of?(AlternateName)
						obj.name += @extensions[idx + 1].name
						@extensions[idx + 1] = nil
					end
					if obj.kind_of?(SymbolicLink)
						obj.linkData += @extensions[idx + 1].linkData
						@extensions[idx + 1] = nil
					end
				end
			end
			@extensions.delete(nil)
		end
		
	end #class RockRidge
	
end #module
