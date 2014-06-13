$:.push("#{File.dirname(__FILE__)}/../../util")
require 'binary_struct'
require 'MiqMemory'

# ////////////////////////////////////////////////////////////////////////////
# // Data definitions.

module Fat32

	BOOT_SECT = BinaryStruct.new([
		'a3',	'jmp_boot',				# Jump to boot loader.
		'a8',	'oem_name',				# OEM Name in ASCII.
		'S',	'bytes_per_sec',	# Bytes per sector: 512, 1024, 2048 or 4096.
		'C',	'sec_per_clus',		# Sectors per cluster, size must be < 32K.
		'S',	'res_sec',				# Reserved sectors.
		'C',	'num_fats',				# Typically 2, but can be 1.
		'S',	'max_root',				# Max files in root dir - 0 FOR FAT32.
		'S',	'num_sec16',			# 16-bit number of sectors in file system (0 if 32-bits needed).
		'C',	'media_type',			# Ususally F8, but can be F0 for removeable.
		'S',	'fat_size16',			# 16-bit number of sectors in FAT, 0 FOR FAT32.
		'S',	'sec_per_track',	# Sectors per track.
		'S',	'num_heads',			# Number of heads.
		'L',	'pre_sec',				# Sectors before the start of the partition.
		'L',	'num_sec32',			# 32-bit number of sectors in the file system (0 if 16-bit num used).
		'L',	'fat_size32',			# 32-bit number of sectors in FAT.
		'S',	'fat_usage',			# Describes how FATs are used: See FU_ below.
		'S',	'version',				# Major & minor version numbers.
		'L',	'root_clus',			# Cluster location of root directory.
		'S',	'fsinfo_sec',			# Sector location of FSINFO structure .
		'S',	'boot_bkup',			# Sector location of boot sector backup.
		'a12',	'reserved1',		# Reserved.
		'C',	'drive_num',			# INT13 drive number.
		'C',	'unused1',				# Unused.
		'C',	'ex_sig',					# If 0x29, then the next three values are valid.
		'L',	'serial_num',			# Volume serial number.
		'a11',	'label',				# Volume label.
		'a8',	'fs_label',				# File system type label, not required.
		# NOTE: MS always uses "FAT32   ". For probe, seek to 66 & verify 0x29,
		# then seek to 82 & read 8, compare with "FAT32   ".
		'a420',	nil,						# Unused.
		'S',	'signature',			# 0xaa55
	])
	SIZEOF_BOOT_SECT = BOOT_SECT.size
	
	DOS_SIGNATURE		= 0xaa55

	FSINFO = BinaryStruct.new([
		'a4',	'sig1',				# Signature - 0x41615252 (RRaA).
		'a480',	nil,				# Unused.
		'a4',	'sig2',				# Signature - 0x61417272 (rrAa).
		'L',	'free_clus',	# Number of free clusters.
		'L',	'next_free',	# Next free cluster.
		'a12',	nil,				# Unused.
		'L',	'sig3',				# Signature - 0xaa550000.
	])
	SIZEOF_FSINFO = FSINFO.size
	
	FSINFO_SIG1	= "RRaA"
	FSINFO_SIG2	= "rrAa"
	FSINFO_SIG3	= 0xaa550000
	
	# ////////////////////////////////////////////////////////////////////////////
	# // Class.

	class BootSect
		FAT_ENTRY_SIZE	= 4
		
		FU_ONE_FAT				= 0x0080
		FU_MSK_ACTIVE_FAT	= 0x000f
		
		CC_NOT_ALLOCATED	= 0
		CC_DAMAGED				= 0x0ffffff7
		CC_END_OF_CHAIN		= 0x0ffffff8
		CC_END_MARK				= 0x0fffffff
		CC_VALUE_MASK			= 0x0fffffff
		
		# Members.
		attr_accessor :bytesPerSector, :bytesPerCluster, :rootCluster
		attr_reader :fatBase, :fatSize, :rootBase, :freeClusters
		attr_reader :fsId, :volName
		
		# Initialization
		def initialize(stream)
			raise "Nil stream" if stream == nil
			
			# Init all.
			@bytesPerSector = 0; @bytesPerCluster = 0; @fatBase = 0;
			@fatSize = 0; @rootBase = 0; @mountable = false
			
			# Buffer stream, read & decode boot sector.
			@stream = stream
			buf = stream.read(SIZEOF_BOOT_SECT)
			raise "Couldn't read boot sector." if buf == nil
			@bs = BOOT_SECT.decode(buf)
			raise "Couldn't decode boot sector." if @bs == nil
			
			# Bytes per sector must be 512, 1024, 2048 or 4096
			bps = @bs['bytes_per_sec']
			raise "Bytes per sector value invalid: #{bps}" if bps != 512 && bps != 1024 && bps != 2048 && bps != 4096
			@bytesPerSector = bps
			
			# Cluster size must be 32K or smaller.
			bpc = @bs['sec_per_clus'] * bps
			raise "Sectors per cluster value invalid: #{bpc} (#{bps}bps * #{@bs['sec_per_clus']}spc)" if bpc > 32768
			@bytesPerCluster = bpc
			
			# Get free clusters.
			stream.seek(@bs['fsinfo_sec'] * @bytesPerSector)
			@fsinfo = FSINFO.decode(stream.read(@bytesPerSector))
			if @fsinfo['sig1'] == 'RRaA' && @fsinfo['sig2'] == 'rrAa' && @fsinfo['sig3'] == 0xaa550000
				@freeClusters = @fsinfo['free_clus']
			else
				@freeClusters = 0
			end
			
			# Expose volume information.
			@fsId = @bs['serial_num']
			@volName = @bs['label']
			
			# Verify FAT32 values according to Carrier.
			raise "Maximum files in root dir invalid: #{@bs['max_root']}\nIs partition FAT12/16?" if @bs['max_root'] != 0
			raise "Number of sectors in FAT invalid: #{@bs['fat_size32']}\nIs partition FAT12/16?" if @bs['fat_size32'] == 0
			raise "Unknown number of sectors in file system." if @bs['num_sec16'] == 0 && @bs['num_sec32'] == 0
			raise "Boot sector signature invalid: 0x#{'%04x' % @bs['signature']}" if @bs['signature'] != 0xaa55
			
			# Calc location of the FAT & root dir.
			@mountable = getLocs
		end
		
		# String rep.
		def to_s
			# NOTE: Non Microsoft tools may not set the file system label (i.e. Win emulators, linux, etc.)
			return @bs['fs_label']
		end
		
		# ////////////////////////////////////////////////////////////////////////////
		# // Class helpers & accessors.
	  
		def isMountable?
			return false if @mountable == nil
			return @mountable
		end
		
		def oemName
			return @bs['oem_name']
		end
		
		# ////////////////////////////////////////////////////////////////////////////
		# // Utility functions.
		
		# Get absolute byte locations of the FAT & the root dir.
		def getLocs
			# Calculate the location of the (active) FAT (loc as absolute byte for seek).
			@fatBase = @bs['res_sec'] * @bytesPerSector
			@fatSize = @bs['fat_size32'] * @bytesPerSector
			fu = @bs['fat_usage']
			if fu & FU_ONE_FAT == FU_ONE_FAT
				@fatBase += @fatSize * (fu & FU_MSK_ACTIVE_FAT)
			end
			return false if @fatBase == 0 || @fatSize == 0
		
			# Calculate the location of the root dir (loc as absolute byte for seek).
			@rootCluster = @bs['root_clus']
			@rootBase = clusToByte(@rootCluster)
			return false if @rootBase == 0
			return true
		end
		
		# Get data for the requested cluster.
		def getCluster(clus)
			raise "Cluster is nil" if clus.nil?
			@stream.seek(clusToByte(clus))
			return @stream.read(@bytesPerCluster)
		end
		
		# Write data to a cluster.
		def putCluster(clus, buf)
			@stream.seek(clusToByte(clus))
			@stream.write(buf, @bytesPerCluster)
		end
		
		# Gets data for the next cluster given current, or nil if end.
		def getNextCluster(clus)
			nxt = getFatEntry(clus)
			return nil if nxt > CC_END_OF_CHAIN
			raise "Damaged cluster in cluster chain" if nxt == CC_DAMAGED
			return [nxt, getCluster(nxt)]
		end
		
		# Return continuous data from a beginning cluster to limit bytes (or EOF).
		def getToLimit(clus, limit)
			
			# Init.
			out = MiqMemory.create_zero_buffer(limit)
			pos = 0
			cur_clus = clus
			
			# How many clusters fill request.
			num = limit.divmod(@bytesPerCluster)
			num_clus = num[0]; num_clus += 1 if num[1] > 0
			
			# Loop until done or EOF.
			while num_clus > 0
				
				# Find number of contiguous clusters & trim by num_clus.
				contig = countContigClusters(cur_clus)
				red_clus = num_clus > contig ? contig : num_clus
				
				# Get data.
				chunk = red_clus * @bytesPerCluster
				@stream.seek(clusToByte(cur_clus))
				out[pos, chunk] = @stream.read(chunk)
				pos += chunk
				
				# Inc current & dec number to read.
				cur_clus += (red_clus - 1); num_clus -= red_clus
				
				# Get next cluster & abort if end of chain.
				cur_clus = getFatEntry(cur_clus)
				break if cur_clus > CC_END_OF_CHAIN
			end
			
			# Return next cluster & data.
			return [cur_clus, out]
		end
		
		# Count the number of continuous clusters from some beginning cluster.
		def countContigClusters(clus)
			cur = clus; nxt = 0
			loop do
				nxt = getFatEntry(cur)
				break if nxt != cur + 1
				cur = nxt; redo
			end
			raise "Damaged cluster in cluster chain" if nxt == CC_DAMAGED
			return cur - clus + 1
		end
		
		# Allocate a number of clusters on a particular cluster chain or start a chain.
		# Start can be anywhere on the chain, but most efficient when just before end.
		# If start is 0 then start a chain (for file data).
		def allocClusters(start, num = 1)
			first = 0; clus = 0
			if start == 0 #Start chain.
				first = getNextAvailableCluster(@rootCluster)
				putFatEntry(first, CC_END_MARK)
				clus = first; num -= 1
			else #Allocate on chain - seek to end.
				clus = start
				#while (nxt = getFatEntry(clus)) <= CC_END_OF_CHAIN do clus = nxt end
				loop do
					nxt = getFatEntry(clus)
					break if nxt > CC_END_OF_CHAIN
					clus = nxt
				end
			end
			# Allocate num clusters, put end mark at end.
			num.times do
				nxt = getNextAvailableCluster(clus)
				first = nxt if first == 0
				putFatEntry(clus, nxt)
				putCluster(nxt, MiqMemory.create_zero_buffer(@bytesPerCluster))
				clus = nxt
				putFatEntry(clus, CC_END_MARK)
			end
			return first
		end
		
		# Start from defined FAT entry and look for next available entry.
		def getNextAvailableCluster(clus)
			loop do
				break if getFatEntry(clus) == 0
				clus += 1
			end
			#while getFatEntry(clus) != 0 do clus += 1 end
			return clus
		end
		
		# Deallocate all clusters on a chain from a starting cluster number.
		def wipeChain(clus)
			loop do
				nxt = getFatEntry(clus)
				putFatEntry(clus, 0)
				break if nxt == 0 #A 0 entry means FAT is inconsistent. Chkdsk may report lost clusters.
				break if nxt == CC_DAMAGED #This should never happen but if it does allow clusters to become lost.
				break if nxt > CC_END_OF_CHAIN
				clus = nxt
			end
		end
		
		# Start from defined cluster number and write data, following allocated cluster chain.
		def writeClusters(start, buf, len = buf.length)
			clus = start; num, leftover = len.divmod(@bytesPerCluster); num += 1 if leftover > 0
			0.upto(num - 1) do |offset|
				local = buf[offset * @bytesPerCluster, @bytesPerCluster]
				if local.length < @bytesPerCluster then local = local + ("\0" * (@bytesPerCluster - local.length)) end
				@stream.seek(clusToByte(clus), IO::SEEK_SET)
				@stream.write(local, @bytesPerCluster)
				break if offset == num - 1 #ugly hack to prevent allocating more than needed.
				nxt = getFatEntry(clus)
				nxt = allocClusters(clus) if nxt > CC_END_OF_CHAIN
				clus = nxt
			end
		end
		
		# Translate a cluster number to an absolute byte location.
		def clusToByte(clus = @rootCluster)
			raise "Cluster is nil" if clus.nil?
			return @bs['res_sec'] * @bytesPerSector + @fatSize * @bs['num_fats'] + (clus - 2) * @bytesPerCluster
		end
		
		# Return the FAT entry for a cluster.
		def getFatEntry(clus)
			@stream.seek(@fatBase + FAT_ENTRY_SIZE * clus)
			return @stream.read(FAT_ENTRY_SIZE).unpack('L')[0] & CC_VALUE_MASK
		end
		
		# Write a FAT entry for a cluster.
		def putFatEntry(clus, value)
			raise "DONT TOUCH THIS CLUSTER: #{clus}" if clus < 3
			@stream.seek(@fatBase + FAT_ENTRY_SIZE * clus)
			@stream.write([value].pack('L'), FAT_ENTRY_SIZE)
		end
		
		def mkClusterMap(clus)
			map = []
			if clus > 0
				map << clus
				loop do
					nxt = getFatEntry(clus)
					break if nxt > CC_END_OF_CHAIN
					clus = nxt
					map << clus
				end
			end
			return map
		end
		
		def dumpFat(numEnt)
			out = ""
			0.upto(numEnt - 1) {|i|
				out += "#{i} #{'%08x' % getFatEntry(i)}\n"
			}
			return out
		end
		
		# Dump object.
		def dump
			out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
			out += "Jump boot (hex)   : #{'%02x %02x %02x' % @bs['jmp_boot'].unpack('C3')}\n"
			out += "OEM Name          : #{@bs['oem_name']}\n"
			out += "Bytes per sector  : #{@bs['bytes_per_sec']}\n"
			out += "Sectors per clus  : #{@bs['sec_per_clus']}\n"
			out += "Reserved sectors  : #{@bs['res_sec']}\n"
			out += "Number of FATs    : #{@bs['num_fats']}\n"
			out += "Max files in root : #{@bs['max_root']}\n"
			out += "Sectors in FS(16) : 0x#{'%04x' % @bs['num_sec16']}\n"
			out += "Media type        : 0x#{'%02x' % @bs['media_type']}\n"
			out += "Sectors in FAT(16): 0x#{'%04x' % @bs['fat_size16']}\n"
			out += "Sectors per track : #{@bs['sec_per_track']}\n"
			out += "Number of heads   : #{@bs['num_heads']}\n"
			out += "Sectors pre start : #{@bs['pre_sec']}\n"
			out += "Sectors in FS(32) : 0x#{'%08x' % @bs['num_sec32']}\n"
			out += "Sectors in FAT(32): 0x#{'%08x' % @bs['fat_size32']}\n"
			out += "FAT usage flags   : 0x#{'%04x' % @bs['fat_usage']}\n"
			out += "Version (MJ/MN)   : 0x#{'%04x' % @bs['version']}\n"
			out += "Root cluster      : #{@bs['root_clus']}\n"
			out += "FSINFO sector     : #{@bs['fsinfo_sec']}\n"
			out += "Backup boot sector: #{@bs['boot_bkup']}\n"
			out += "Reserved          : '#{@bs['reserved1']}'\n"
			out += "Drive number      : #{@bs['drive_num']}\n"
			out += "Extended signature: 0x#{'%02x' % @bs['ex_sig']} (0x29?)\n"
			out += "Serial number     : 0x#{'%08x' % @bs['serial_num']}\n"
			out += "Label             : '#{@bs['label']}'\n"
			out += "File Sys label    : '#{@bs['fs_label']}'\n"
			out += "Signature         : 0x#{'%04x' % @bs['signature']} (0xaa55?)\n"
			return out
		end
		
	end
end # module Fat32
