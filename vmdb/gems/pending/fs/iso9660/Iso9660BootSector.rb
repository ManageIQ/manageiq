require 'Iso9660Util'

$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'
require 'miq-unicode'

module Iso9660
	
	class BootSector
		
		# Universal Volume Descriptor ID.
		DESCRIPTOR_ID = "CD001"
		
		# Volume descriptor types.
		TYPE_BOOT				= 0	# The descriptor is a boot record.
		TYPE_PRIM_DESC	= 1	# The descriptor is a primary volume descriptor.
		TYPE_SUPP_DESC	= 2 # The descriptor is a supplementary volume descriptor.
		TYPE_PART_DESC	= 3 # The descriptor is a volume partition descriptor.
		TYPE_TERMINATOR	= 255 # Marks the end of descriptor records.
		# NOTE: the spec says terminator is 4, but it seems to be 255.
		
		# This serves as both the primary and supplementary descriptor structure.
		VOLUME_DESCRIPTOR = BinaryStruct.new([
			'C',		'desc_type',								# TYPE_ enum.
			'a5',		'id',												# Always "CD001".
			'C',		'version',									# Must be 1.
			'C',		'vol_flags',								# Unused on primary.
			'a32',	'system_id',								# An 'extra' label.
			'a32',	'volume_id',								# Usually known as label.
			'a8',		'unused2',
			'L',		'vol_space_sizeLE',					# Size in sectors.
			'L',		'vol_space_sizeBE',
			'a32',	'esc_sequences',						# Unused on primary, Joliet CDs do not always record escape sequences (assume UCS-2L3).
			'S',		'vol_set_sizeLE',
			'S',		'vol_set_sizeBE',
			'S',		'vol_seq_numberLE',
			'S',		'vol_seq_numberBE',
			'S',		'log_block_sizeLE',					# Sector size in bytes (so far, alwyas 2048).
			'S',		'log_block_sizeBE',
			'L',		'path_table_sizeLE',				# This implementation ignores the path tables.
			'L',		'path_table_sizeBE',
			'S',		'type_1_path_tableLE',
			'S',		'type_1_path_tableBE',
			'S',		'opt_type_1_path_tableLE',
			'S',		'opt_type_1_path_tableBE',
			'S',		'type_m_path_tableLE',
			'S',		'type_m_path_tableBE',
			'S',		'opt_type_m_path_tableLE',
			'S',		'opt_type_m_path_tableBE',
			'a34',	'root_dir_record',					# DirectoryEntry representing root dir.
			'a128',	'vol_set_id',
			'a128',	'publisher_id',
			'a128',	'preparer_id',
			'a128',	'application_id',
			'a37',	'copyright_file_id',
			'a37',	'abstract_file_id',
			'a37',	'biblographic_file_id',
			'a17',	'creation_date',						# Dates are in ISO long date format.
			'a17',	'modification_date',
			'a17',	'experation_date',
			'a17',	'effective_date',
			'C',		'file_structure_version',		# Must be 1.
			'C',		'unused4',
			'a512',	'application_data',
			'a653',	'unused5'
		])
		SIZEOF_VOLUME_DESCRIPTOR = VOLUME_DESCRIPTOR.size
		
		attr_reader :sectorSize, :descType, :fsId, :volName
		attr_reader :cTime, :mTime, :expirationDate, :effectiveDate
		attr_reader :rootEntry, :recId, :suff
		
		def initialize(stream, joliet = false)
			raise "Nil stream" if stream.nil?
			@stream = stream
			@isJoliet = joliet
			@jolietVerified = false
			
			# Get the suffix to use for all members.
			@suff = getSuffix
			
			# Read & check descriptor.
			@bs = VOLUME_DESCRIPTOR.decode(@stream.read(SIZEOF_VOLUME_DESCRIPTOR))
			@descType = @bs['desc_type']
			raise "Descriptor type mismatch (type is #{@descType})" if @descType != (@isJoliet ? TYPE_SUPP_DESC : TYPE_PRIM_DESC)
			@recId = @bs['id']
			raise "Descriptor ID mismatch" if @recId != "CD001"
			raise "Descriptor version mismatch" if @bs['version'] != 1
			raise "File structure version mismatch" if @bs['file_structure_version'] != 1
			
			# If this is supposed to be Joliet then try to verify.
			if @isJoliet
				esc = @bs['esc_sequences'].strip
				if esc[0, 2] == '%/'
					level = esc[2, 1]
					@jolietVerified = true if level == '@' or level == 'C' or level == 'E'
				end
			end
			# From now on, assume Joliet if @isJoliet is true.
			# If verification fails it's up to Directory & DirectoryEntry to be careful.
			
			# Read fs params.
			@sectorSize = @bs["log_block_size#{@suff}"]
			@volName = @bs['volume_id']
			@volName.Ucs2ToAscii! if @isJoliet
			# fsId can come from Rock Ridge ext if present.
			# Don't forget there's a serial number too if RR isn't there.
			@cTime = Iso9660Util.IsoToRubyDate(@bs['creation_date'])
			@mTime = Iso9660Util.IsoToRubyDate(@bs['modification_date'])
			@expirationDate = Iso9660Util.IsoToRubyDate(@bs['expiration_date'])
			@effectiveDate = Iso9660Util.IsoToRubyDate(@bs['effective_date'])
			
			# Filesystem root.
			@rootEntry = @bs['root_dir_record']
		end
		
		def diskSize
			@bs["vol_space_size#{@suff}"] * @sectorSize
		end
		
		def getSectors(sector, num = 1)
			@stream.seek(sector * @sectorSize)
			@stream.read(@sectorSize * num)
		end
		
		def isJoliet?
			return @isJoliet
		end
		
		def getSuffix
			if Platform::ARCH == :x86
				@@suff = 'LE'
			else
				# Other architectures are bi-endian and must be determined at run time.
				p = [0xaa, 0x55].pack('N')
				u = p.unpack('L')
				@@suff = u == 0xaa55 ? 'BE' : 'LE'
			end
		end
		
		# This is a raw dump with no character set conversion.
		def dump
			out = "\n"
			out += "Type            : #{@bs['desc_type']}\n"
			out += "Record ID       : #{@bs['id']}\n"
			out += "Version         : #{@bs['version']}\n"
			out += "System ID       : #{@bs['system_id'].strip}\n"
			out += "Volume ID       : #{@volName}\n"
			out += "Vol space size  : #{@bs["vol_space_size#{@suff}"]} (sectors)\n"
			out += "Vol set size    : #{@bs["vol_set_size#{@suff}"]}\n"
			out += "Vol sequence num: #{@bs["vol_seq_number#{@suff}"]}\n"
			out += "Logical blk size: #{@bs["log_block_size#{@suff}"]} (sector size)\n"
			out += "Path table size : #{@bs["path_table_size#{@suff}"]}\n"
			out += "Type 1 path tbl : #{@bs["type_1_path_table#{@suff}"]}\n"
			out += "Opt type 1 pth  : #{@bs["opt_type_1_path_table#{@suff}"]}\n"
			out += "Type M path tbl : #{@bs["type_m_path_table#{@suff}"]}\n"
			out += "Opt type M pth  : #{@bs["opt_type_m_path_table#{@suff}"]}\n"
			out += "Vol set ID      : #{@bs['vol_set_id'].strip}\n"
			out += "Publisher ID    : #{@bs['publisher_id'].strip}\n"
			out += "Preparer ID     : #{@bs['preparer_id'].strip}\n"
			out += "Application ID  : #{@bs['application_id'].strip}\n"
			out += "Copyright       : #{@bs['copyright_file_id'].strip}\n"
			out += "Abstract        : #{@bs['abstract_file_id'].strip}\n"
			out += "Biblographic    : #{@bs['biblographic_file_id'].strip}\n"
			out += "Creation date   : #{@bs['creation_date'].strip} (#{@cTime}, tz = #{Iso9660Util.GetTimezone(@bs['creation_date'])})\n"
			out += "Mod date        : #{@bs['modification_date'].strip} (#{@mTime}, tz = #{Iso9660Util.GetTimezone(@bs['modification_date'])})\n"
			out += "Expiration date : #{@bs['experation_date'].strip} (#{@expirationDate}, tz = #{Iso9660Util.GetTimezone(@bs['experation_date'])})\n"
			out += "Effective date  : #{@bs['effective_date'].strip} (#{@effectiveDate}, tz = #{Iso9660Util.GetTimezone(@bs['effective_date'])})\n"
			out += "File strct ver  : #{@bs['file_structure_version']}\n"
			out += "Application data: #{@bs['application_data'].strip}\n"
		end
		
	end #class
end #module
