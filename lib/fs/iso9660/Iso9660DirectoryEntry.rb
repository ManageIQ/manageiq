require 'Iso9660Util'
require 'Iso9660RockRidge'

$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'
require 'miq-unicode'

module Iso9660
	
	# FlagBits: FB_
	FB_HIDDEN			=	0x01	# 0 if not hidden.
	FB_DIRECTORY	= 0x02	# 0 if file.
	FB_ASSOCIATED	= 0x04	# 0 if not 'associated' (?)
	FB_RFS				= 0x08	# RecordFormatSpecified: 0 if not.
	FB_PS					= 0x10	# PermissionsSpecified: 0 if not.
	FB_UNUSED1		= 0x20	# No info.
	FB_UNUSED2		= 0x40	# No info.
	FB_NOT_LAST		= 0x80	# 0 if last entry.
	
	# Extensions.
	EXT_NONE			= 0
	EXT_JOLIET		= 1
	EXT_ROCKRIDGE	= 2
	
	class DirectoryEntry
	
		DIR_ENT = BinaryStruct.new([
			'C',	'length',						# Bytes, must be even.
			'C',	'ext_attr_length',	# Sectors.
			'L',	'extentLE',					# First sector of data.
			'L',	'extentBE',
			'L',	'sizeLE',						# Size of data in bytes.
			'L',	'sizeBE',
			'a7',	'date',							# ISODATE
			'C',	'flags',						# Flags, see FB_ above.
			'C',	'file_unit_size',		# For interleaved files: not supported.
			'C',	'interleave',				# Not supported.
			'S',	'vol_seq_numLE',		# Not used.
			'S',	'vol_seq_numBE',
			'C',	'name_len',					# Bytes.
		])
		# Here follows a name. Character set is limited ASCII.
		# Here follows an optional padding byte (if name_len is even).
		# Here follows unspecified extra data, size is included in member length.
		SIZEOF_DIR_ENT = DIR_ENT.size
		
		attr_reader :date, :length, :myEnt
		
		def initialize(data, suff, flags = EXT_NONE)
			raise "Data is nil." if data.nil?
			
			@suff = suff
			# Get data.
			@de = DIR_ENT.decode(data)
			@length = @de['length']
			@myEnt = data[0...@length]
			@date = Iso9660Util.IsoShortToRubyDate(@de['date'])
			offset = SIZEOF_DIR_ENT
			len = @de['name_len']
			if len > 0
				name = data[offset...(offset + len)]
				# Convert 00 to dot and 01 to dotdot.
				if len == 1 and (name[0] == 0 or name[0] == 1)
					name = "." if name[0] == 0
					name = ".." if name[0] == 1
				else
					name.Ucs2ToAscii! if flags & EXT_JOLIET == EXT_JOLIET
				end
				offset += len
				offset += 1 if len & 1 == 0 && (flags & EXT_JOLIET == 0) # Cheap test for even/odd.
			end
			@de['name'] = name
			@de['sua'] = data[offset...@de['length'] - 1] if offset < @de['length']
			processRockRidge if flags & EXT_ROCKRIDGE == EXT_ROCKRIDGE
		end
		
		def name
			@de['name']
		end
		
		def sua
			@de['sua']
		end
		
		def fileStart
			@de["extent#{@suff}"]
		end
		
		def fileSize
			return @de["size#{@suff}"] if @rr.nil?
			size = checkExt("linkData")
			return size.size unless size.nil?
			@de["size#{@suff}"]
		end
		
		def isFile?
			@de['flags'] & FB_DIRECTORY == 0
		end
		
		def isDir?
			@de['flags'] & FB_DIRECTORY == FB_DIRECTORY
		end
		
		def isSymLink?
			return false if @rr.nil?
			isLink = checkExt("linkData")
			return true unless isLink.nil?
			return false
		end
		
		def checkExt(sym)
			return nil if @rr.nil?
			res = nil
			@rr.extensions.each do |extension|
				ext = extension.ext
				begin
					res = eval("ext.#{sym}")
				rescue
					break unless res.nil?
				end
			end
			return res
		end
		
		def processRockRidge
			return if self.length == 0
			@rr = RockRidge.new(self)
			# Check for alternate name.
			new_name = checkExt("name")
			@de['name'] = new_name unless new_name.nil?
		end
		
		def dump
			out = ""
			out << "Length  : #{@de['length']}\n"
			out << "Attr len: #{@de['ext_attr_length']} (sectors)\n"
			out << "Data sec: #{@de["extent#{@suff}"]}\n"
			out << "Size    : #{@de["size#{@suff}"]}\n"
			out << "Date    : #{@date}\n"
			out << "Flags   : 0x#{'%02x' % @de['flags']}\n"
			out << "Name len: #{@de['name_len']}\n"
			out << "Name    : #{@de['name']}\n"
			if @de['sua']
				out << "System U:\n"
				out << @de['sua'].hex_dump
			end
			return out
		end
		
	end #class
	
end #module
