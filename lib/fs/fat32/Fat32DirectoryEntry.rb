require 'stringio'

$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'
require 'miq-unicode'

# ////////////////////////////////////////////////////////////////////////////
# // Data definitions.

# TODO: reserved1 is the infamous magic number. Somehow it works to preserve
# case on Windows XP. Nobody seems to know how. Here it is always set to 0
# (which yields uppercase names on XP).

module Fat32

	DIR_ENT_SFN = BinaryStruct.new([
		'a11',	'name',					# If name[0] = 0, unallocated; if name[0] = 0xe5, deleted. DOES NOT INCLUDE DOT.
		'C',	'attributes',			# See FA_ below. If 0x0f then LFN entry.
		'C',	'reserved1',			# Reserved.
		'C',	'ctime_tos',			# Created time, tenths of second.
		'S',	'ctime_hms',			# Created time, hours, minutes & seconds.
		'S',	'ctime_day',			# Created day.
		'S',	'atime_day',			# Accessed day.
		'S',	'first_clus_hi',	# Hi 16-bits of first cluster address.
		'S',	'mtime_hms',			# Modified time, hours, minutes & seconds.
		'S',	'mtime_day',			# Modified day.
		'S',	'first_clus_lo',	# Lo 16-bits of first cluster address.
		'L',	'file_size',			# Size of file (0 for directories).
	])

	DIR_ENT_LFN = BinaryStruct.new([
		'C',	'seq_num',		# Sequence number, bit 6 marks end, 0xe5 if deleted.
		'a10',	'name',			# UNICODE chars 1-5 of name.
		'C',	'attributes',	# Always 0x0f.
		'C',	'reserved1',	# Reserved.
		'C',	'checksum',		# Checksum of SFN entry, all LFN entries must match.
		'a12',	'name2',		# UNICODE chars 6-11 of name.
		'S',	'reserved2',	# Reserved.
		'a4',	'name3'				# UNICODE chars 12-13 of name.
	])
	
	CHARS_PER_LFN		= 13
	LFN_NAME_MAXLEN	= 260
	DIR_ENT_SIZE		= 32
	ATTRIB_OFFSET		= 11
	
	# ////////////////////////////////////////////////////////////////////////////
	# // Class.

	class DirectoryEntry
		
		# From the UTF-8 perspective.
		# LFN name components: entry hash name, char offset, length.
		LFN_NAME_COMPONENTS = [
			['name',	 0, 5],
			['name2',	 5, 6],
			['name3',	11, 2]
		]
		# Name component second sub access names.
		LFN_NC_HASHNAME	= 0
		LFN_NC_OFFSET		= 1
		LFN_NC_LENGTH		= 2
		
		# SFN failure cases.
		SFN_NAME_LENGTH		= 1
		SFN_EXT_LENGTH		= 2
		SFN_NAME_NULL			= 3
		SFN_NAME_DEVICE		= 4
		SFN_ILLEGAL_CHARS	= 5
		
		# LFN failure cases.
		LFN_NAME_LENGTH		= 1
		LFN_NAME_DEVICE		= 2
		LFN_ILLEGAL_CHARS	= 3
		
		# FileAttributes
		FA_READONLY		= 0x01
		FA_HIDDEN			= 0x02
		FA_SYSTEM			= 0x04
		FA_LABEL			= 0x08
		FA_DIRECTORY	= 0x10
		FA_ARCHIVE		= 0x20
		FA_LFN				= 0x0f
		
		# DOS time masks.
		MSK_DAY		= 0x001f	# Range: 1 - 31
		MSK_MONTH	= 0x01e0	# Right shift 5, Range: 1 - 12
		MSK_YEAR	= 0xfe00	# Right shift 9, Range: 127 (add 1980 for year).
		MSK_SEC		= 0x001f	# Range: 0 - 29 WARNING: 2 second granularity on this.
		MSK_MIN		= 0x07e0	# Right shift 5, Range: 0 - 59
		MSK_HOUR	= 0xf800	# Right shift 11, Range: 0 - 23
		
		# AllocationFlags
		AF_NOT_ALLOCATED	= 0x00
		AF_DELETED				= 0xe5
		AF_LFN_LAST				= 0x40
		
		# Members.
		attr_reader :unused, :name, :dirty
		attr_accessor :parentCluster, :parentOffset
		# NOTE: Directory is responsible for setting parent.
		# These describe the cluster & offset of the START of the directory entry.
		
		# Initialization
		def initialize(buf = nil)
			# Create for write.
			if buf == nil
				self.create
				return
			end
			
			# Handle possibly multiple LFN records.
			data = StringIO.new(buf); @lfn_ents = []
			checksum = 0; @name = ""
			loop do
				buf = data.read(DIR_ENT_SIZE)
				if buf == nil
					@unused = ""
					return
				end
				
				# If attribute contains 0x0f then LFN entry.
				isLfn = buf[ATTRIB_OFFSET] == FA_LFN
				@dir_ent = isLfn ? DIR_ENT_LFN.decode(buf) : DIR_ENT_SFN.decode(buf)
				break if !isLfn
				
				# Ignore this entry if deleted or not allocated.
				af = @dir_ent['seq_num']
				if af == AF_DELETED || af == AF_NOT_ALLOCATED
					@name = @dir_ent['seq_num']
					@unused = data.read()
					return
				end
				
				# Set checksum or make sure it's the same
				checksum = @dir_ent['checksum'] if checksum == 0
				raise "Directory entry LFN checksum mismatch." if @dir_ent['checksum'] != checksum
				
				# Track LFN entry, gather names & prepend to name.
				@lfn_ents << @dir_ent
				@name = getLongNameFromEntry(@dir_ent) + @name
			end #LFN loop
			
			# Push the rest of the data back.
			@unused = data.read()
			
			# If this is the last record of an LFN chain, check the checksum.
			if checksum != 0
				csum = calcChecksum
				if csum != checksum
					puts "Directory entry SFN checksum does not match LFN entries:"
					puts "Got 0x#{'%02x' % csum}, should be 0x#{'%02x' % checksum}."
					puts "Non LFN OS corruption?"
					puts dump
					raise "Checksum error"
				end
			end
			
			# Populate name if not LFN.
			if @name == "" && !@dir_ent['name'].empty?
				@name = @dir_ent['name'][0, 8].strip
				ext = @dir_ent['name'][8, 3].strip
				@name += "." + ext unless ext.empty?
			end
		end

		# ////////////////////////////////////////////////////////////////////////////
		# // Class helpers & accessors.
		
		# Return this entry as a raw string.
		def raw
			out = ""
			@lfn_ents.each {|ent| out += BinaryStruct.encode(ent, DIR_ENT_LFN)} if @lfn_ents
			out += BinaryStruct.encode(@dir_ent, DIR_ENT_SFN)
		end
		
		# Number of dir ent structures (both sfn and lfn).
		def numEnts
			num = 1
			num += @lfn_ents.size if @lfn_ents
			return num
		end
		
		# Return normalized 8.3 name.
		def shortName
			name = @dir_ent['name'][0, 8].strip
			ext  = @dir_ent['name'][8, 3].strip
			name += "." + ext if ext != ""
			return name
		end
		
		# Construct & return long name from lfn entries.
		def longName
			return nil if @lfn_ents == nil
			name = ""
			@lfn_ents.reverse.each {|ent| name += getLongNameFromEntry(ent)}
			return name
		end
		
		# WRITE: change filename.
		def name=(filename)
			@dirty = true
			# dot and double dot are special cases (no processing please).
			if filename != "." and filename != ".."
				if filename.size > 12 || (not filename.include?(".") && filename.size > 8)
					mkLongName(filename)
					@name = self.longName
				else
					@dir_ent['name'] = mkSfn(filename)
					@name = self.shortName
				end
			else
				@dir_ent['name']= filename.ljust(11)
				@name = filename
			end
		end
		
		# WRITE: change magic number.
		def magic=(magic)
			@dirty = true
			@dir_ent['reserved1'] = magic
		end
		
		def magic
			return @dir_ent['reserved1']
		end
		
		# WRITE: change attribs.
		def setAttribute(attrib, set = true)
			@dirty = true
			if set
				@dir_ent['attributes'] |= attrib
			else
				@dir_ent['attributes'] &= (~attrib)
			end
		end
		
		# WRITE: change length.
		def length=(len)
			@dirty = true
			@dir_ent['file_size'] = len
		end
		
		# WRITE: change first cluster.
		def firstCluster=(first_clus)
			@dirty = true
			@dir_ent['first_clus_hi'] = (first_clus >> 16)
			@dir_ent['first_clus_lo'] = (first_clus & 0xffff)
		end
		
		# WRITE: change access time.
		def aTime=(tim)
			@dirty = true
			time, day = rubyToDosTime(tim)
			@dir_ent['atime_day'] = day
		end
		
		# To support root dir times (all zero).
		def zeroTime
			@dirty = true
			@dir_ent['atime_day'] = 0
			@dir_ent['ctime_tos'] = 0; @dir_ent['ctime_hms'] = 0; @dir_ent['ctime_day'] = 0
			@dir_ent['mtime_hms'] = 0; @dir_ent['mtime_day'] = 0
		end
		
		# WRITE: change modified (written) time.
		def mTime=(tim)
			@dirty = true
			@dir_ent['mtime_hms'], @dir_ent['mtime_day'] = rubyToDosTime(tim)
		end
		
		# WRITE: write or rewrite directory entry.
		def writeEntry(bs)
			return if not @dirty
			cluster = @parentCluster; offset = @parentOffset
			buf = bs.getCluster(cluster)
			if @lfn_ents
				@lfn_ents.each {|ent|
					buf[offset...(offset + DIR_ENT_SIZE)] = BinaryStruct.encode(ent, DIR_ENT_LFN)
					offset += DIR_ENT_SIZE
					if offset >= bs.bytesPerCluster
						bs.putCluster(cluster, buf)
						cluster, buf = bs.getNextCluster(cluster)
						offset = 0
					end
				}
			end
			buf[offset...(offset + DIR_ENT_SIZE)] = BinaryStruct.encode(@dir_ent, DIR_ENT_SFN)
			bs.putCluster(cluster, buf)
			@dirty = false
		end
		
		# WRITE: delete file.
		def delete(bs)
			# Deallocate data chain.
			bs.wipeChain(self.firstCluster) if self.firstCluster != 0
			# Deallocate dir entry.
			if @lfn_ents then @lfn_ents.each {|ent| ent['seq_num'] = AF_DELETED} end
			@dir_ent['name'][0] = AF_DELETED
			@dirty = true
			self.writeEntry(bs)
		end
		
		def close(bs)
			writeEntry(bs) if @dirty
		end
		
		def attributes
			return @dir_ent['attributes']
		end
		
		def length
			return @dir_ent['file_size']
		end
		
		def firstCluster
			return (@dir_ent['first_clus_hi'] << 16) + @dir_ent['first_clus_lo']
		end
		
		def isDir?
			return true if @dir_ent['attributes'] & FA_DIRECTORY == FA_DIRECTORY
			return false
		end
		
		def mTime
			return dosToRubyTime(@dir_ent['mtime_day'], @dir_ent['mtime_hms'])
		end
		
		def aTime
			return dosToRubyTime(@dir_ent['atime_day'], 0)
		end
		
		def cTime
			return dosToRubyTime(@dir_ent['ctime_day'], @dir_ent['ctime_hms'])
		end
				
		# ////////////////////////////////////////////////////////////////////////////
		# // Utility functions.
		
		def getLongNameFromEntry(ent)
			pre_name = ""; hashNames = %w(name name2 name3)
			hashNames.each {|name|
				n = ent["#{name}"]
				pre_name += n.gsub(/\377/, "").UnicodeToUtf8.gsub(/\000/, "")
			}
			return pre_name
		end
		
		def incShortName
			@dirty = true
			num = @dir_ent['name'][7].to_i
			num += 1
			raise "More than 9 files with name: #{@dir_ent['name'][0, 6]}" if num > 57
			@dir_ent['name'][7] = num
			csum = calcChecksum()
			if @lfn_ents
				@lfn_ents.each {|ent| ent['checksum'] = csum}
			end
		end
		
		def create
			@dirty = true
			@dir_ent = Hash.new
			@dir_ent['name'] = "FILENAMEEXT"
			@name = self.shortName
			@dir_ent['attributes'] = FA_ARCHIVE
			@dir_ent['ctime_tos'] = 0
			@dir_ent['ctime_hms'], @dir_ent['ctime_day'] = rubyToDosTime(Time.now)
			@dir_ent['atime_day'] = @dir_ent['ctime_day']
			@dir_ent['mtime_hms'], @dir_ent['mtime_day'] = @dir_ent['ctime_hms'], @dir_ent['ctime_day']
			# Must fill all members or BinaryStruct.encode fails.
			self.magic = 0x00; self.length = 0; self.firstCluster = 0 #magic used to be 0x18
		end
		
		def mkLongName(name)
			@lfn_ents	= mkLfn(name)
			@dir_ent['name'] = mkSfn(name)
			# Change magic number to 0.
			@dir_ent['reserved1'] = 0
			# Do checksums in lfn entries.
			csum = calcChecksum()
			@lfn_ents.each {|ent| ent['checksum'] = csum}
		end
		
		def mkLfn(name)
			name = mkLegalLfn(name)
			lfn_ents = []
			# Get number of LFN entries necessary to encode name.
			ents, leftover = name.length.divmod(CHARS_PER_LFN)
			if leftover > 0
				ents += 1
				name += "\000"
			end
			# Split out & convert name components.
			1.upto(ents) {|ent_num|
				ent = {}; ent['attributes'] = FA_LFN; ent['seq_num'] = ent_num
				ent['reserved1'] = 0; ent['reserved2'] = 0;
				LFN_NAME_COMPONENTS.each {|comp|
					chStart = (ent_num - 1) * CHARS_PER_LFN + comp[LFN_NC_OFFSET]
					if chStart > name.length
						ent["#{comp[LFN_NC_HASHNAME]}"] = "\377" * (comp[LFN_NC_LENGTH] * 2)
					else
						ptName = name[chStart, comp[LFN_NC_LENGTH]]
						ptName.Utf8ToUnicode!
						if ptName.length < comp[LFN_NC_LENGTH] * 2
							ptName += "\377" * (comp[LFN_NC_LENGTH] * 2 - ptName.length)
						end
						ent["#{comp[LFN_NC_HASHNAME]}"] = ptName
					end
				}
				lfn_ents << ent
			}
			lfn_ents.reverse!
			lfn_ents[0]['seq_num'] |= AF_LFN_LAST
			return lfn_ents
		end
		
		def mkSfn(name)
			return mkLegalSfn(name)
		end
		
		def isIllegalSfn(name)
			# Check: name length, extension length, NULL file name,
			# device names as file names & illegal chars.
			return SFN_NAME_LENGTH if name.length > 12
			extpos = name.reverse.index(".")
			return SFN_EXT_LENGTH if extpos > 3
			return SFN_NAME_NULL if extpos == 0
			fn = name[0...extpos].downcase
			return SFN_NAME_DEVICE if checkForDeviceNames(fn)
			return SFN_ILLEGAL_CHARS if name.index(/[;+=\[\]',\"*\\<>\/?\:|]/) != nil
			return false
		end
		
		def checkForDeviceName(fn)
			%w[aux com1 com2 com3 com4 lpt lpt1 lpt2 lpt3 lpt4 mailslot nul pipe prn].each {|bad|
				return true if fn == bad
			}
			return false
		end
		
		def mkLegalSfn(name)
			name = name.upcase; name = name.delete(" ")
			name = name + "." if not name.include?(".")
			extpos = name.reverse.index(".")
			if extpos == 0 then ext = "" else ext = name[-extpos, 3] end
			fn = name[0, (name.length - extpos - 1)]
			fn = fn[0, 6] + "~1" if fn.length > 8
			return (fn.ljust(8) + ext.ljust(3)).gsub(/[;+=\[\]',\"*\\<>\/?\:|]/, "_")
		end
		
		def isIllegalLfn(name)
			return LFN_NAME_LENGTH if name.length > LFN_NAME_MAXLEN
			return LFN_ILLEGAL_CHARS if name.index(/\/\\:><?/) != nil
			return false
		end
		
		def mkLegalLfn(name)
			name = name[0...LFN_NAME_MAXLEN] if name.length > LFN_NAME_MAXLEN
			return name.gsub(/\/\\:><?/, "_")
		end
		
		def calcChecksum
			name = @dir_ent['name']; csum = 0
			0.upto(10) {|i|
				csum = ((csum & 1 == 1 ? 0x80 : 0) + (csum >> 1) + name[i]) & 0xff
			}
			return csum
		end
	  
		def dosToRubyTime(dos_day, dos_time)
			# Extract d,m,y,s,m,h & range check.
			day = dos_day & MSK_DAY; day = 1 if day == 0
			month = (dos_day & MSK_MONTH) >> 5; month = 1 if month == 0
			month = month.modulo(12) if month > 12
			year = ((dos_day & MSK_YEAR) >> 9) + 1980 #DOS year epoc is 1980.
			# Extract seconds, range check & expand granularity.
			sec = (dos_time & MSK_SEC); sec = sec.modulo(29) if sec > 29; sec *= 2
			min = (dos_time & MSK_MIN) >> 5; min = min.modulo(59) if min > 59
			hour = (dos_time & MSK_HOUR) >> 11; hour = hour.modulo(23) if hour > 23
			# Make a Ruby time.
			return Time.mktime(year, month, day, hour, min, sec)
		end
		
		def rubyToDosTime(tim)
			# Time
			sec = tim.sec; sec -= 1 if sec == 60 #correction for possible leap second.
			sec = (sec / 2).to_i #dos granularity is 2sec.
			min = tim.min; hour = tim.hour
			dos_time = (hour << 11) + (min << 5) + sec
			# Day
			day = tim.day; month = tim.month
			# NOTE: This fails after 2107.
			year = tim.year - 1980 #DOS year epoc is 1980.
			dos_day = (year << 9) + (month << 5) + day
			return dos_time, dos_day
		end
		
		# Dump object.
		def dump
			out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
			if @lfn_ents
				out += "LFN Entries:\n"
				@lfn_ents.each {|ent|
					out += "Sequence num : 0x#{'%02x' % ent['seq_num']}\n"
					n = ent['name']; n.UnicodeToUtf8! unless n == nil
					out += "Name1        : '#{n}'\n"
					out += "Attributes   : 0x#{'%02x' % ent['attributes']}\n"
					out += "Reserved1    : 0x#{'%02x' % ent['reserved1']}\n"
					out += "Checksum     : 0x#{'%02x' % ent['checksum']}\n"
					n = ent['name2']; n.UnicodeToUtf8! unless n == nil
					out += "Name2        : '#{n}'\n"
					out += "Reserved2    : 0x#{'%04x' % ent['reserved2']}\n"
					n = ent['name3']; n.UnicodeToUtf8! unless n == nil
					out += "Name3        : '#{n}'\n\n"
				}
			end
			out += "SFN Entry:\n"
			out += "Name         : #{@dir_ent['name']}\n"
			out += "Attributes   : 0x#{'%02x' % @dir_ent['attributes']}\n"
			out += "Reserved1    : 0x#{'%02x' % @dir_ent['reserved1']}\n"
			out += "CTime, tenths: 0x#{'%02x' % @dir_ent['ctime_tos']}\n"
			out += "CTime, hms   : 0x#{'%04x' % @dir_ent['ctime_hms']}\n"
			out += "CTime, day   : 0x#{'%04x' % @dir_ent['ctime_day']} (#{cTime})\n"
			out += "ATime, day   : 0x#{'%04x' % @dir_ent['atime_day']} (#{aTime})\n"
			out += "First clus hi: 0x#{'%04x' % @dir_ent['first_clus_hi']}\n"
			out += "MTime, hms   : 0x#{'%04x' % @dir_ent['mtime_hms']}\n"
			out += "MTime, day   : 0x#{'%04x' % @dir_ent['mtime_day']} (#{mTime})\n"
			out += "First clus lo: 0x#{'%04x' % @dir_ent['first_clus_lo']}\n"
			out += "File size    : 0x#{'%08x' % @dir_ent['file_size']}\n"
		end
		
	end
end # module Fat32
