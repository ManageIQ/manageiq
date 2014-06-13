$:.push("#{File.dirname(__FILE__)}/../../../util")

require 'binary_struct'
require 'NtfsMftEntry'

require 'rufus/lru'

#######################################################################################
# A good source of disk-layout information is in open-source ntfs-3g/include/ntfs-3g/layout.h
# A good source of understanding how to use this data is in Brian Carrier's File System Forensic Analysis
#######################################################################################

module NTFS
		
	# The boot parameters block, sector 0 byte 0 of a bootable volume.
	BOOT_PARAMETERS_BLOCK = BinaryStruct.new([
		'a3', 'jmp_boot_loader',          # Jump to boot loader
		'a8', 'oem_name',                 # OEM Name (should be 'NTFS    ')

		# BIOS Parameter Block            
		'S',  'bytes_per_sector',         # Bytes per sector. The size of a hardware sector. For most disks used in the United States, the value of this field is 512.
		'C1', 'sectors_per_cluster',      # Sectors per cluster
		'S',  'reserved_sectors',         # Reserved sectors. Always 0 because NTFS places the boot sector at the beginning of the partition. If the value is not 0, NTFS fails to mount the volume.
		'C1', 'fats',                     # Value must be 0 or NTFS fails to mount the volume
		'S',  'root_entries',             # Value must be 0 or NTFS fails to mount the volume
		'S',  'sectors',                  # Value must be 0 or NTFS fails to mount the volume
		'C1', 'media_descriptor',         # Provides information about the media being used. A value of 0xF8 indicates a hard disk and 0xF0 indicates a high-density 3.5-inch floppy disk. Media descriptor entries are a legacy of MS-DOS FAT16 disks and are not used in Windows Server 2003.
		'S',  'sectors_per_fat',          # Value must be 0 or NTFS fails to mount the volume
		'S',  'sectors_per_track',        # Required to boot Windows
		'S',  'number_of_heads',          # Required to boot Windows
		'L',  'hidden_sectors',           # Offset to the start of the partition relative to the disk in sectors.  Required to boot Windows
		'L',  'large_sectors',            # Must be 0

		# Extended BIOS Parameter Block            
		'C1', 'physical_drive',           # 0x00 floppy, 0x80 hard disk
		'C1', 'current_head',             # Must be 0
		'C1', 'extended_boot_signature',  # 0x80
		'C1', 'reserved2',
		'Q',  'sectors_per_volume',        # Number of sectors in volume. Gives maximum volume size of 2^63 sectors. Assuming standard sector size of 512 bytes, the maximum byte size is approx. 4.7x10^21 bytes.
		'Q',  'mft_lcn',                   # Logical Cluster Number for the File $MFT.     Identifies the location of the                      MFT by using its logical cluster number.
		'Q',  'mftmirr_lcn',               # Logical Cluster Number for the File $MFTMirr. Identifies the location of the mirrored copy of the MFT by using its logical cluster number.
		'c1', 'clusters_per_mft_record',   # Mft record size in clusters.  NTFS creates a file record for each file and a folder record for each folder that is created on an NTFS volume. Files and folders smaller than this size are contained within the MFT. If this number is positive (up to 7F), then it represents clusters per MFT record. If the number is negative (80 to FF), then the size of the file record is 2 raised to the absolute value of this number.
		'a3', 'reserved0',
		'c1', 'clusters_per_index_record', # Index block size in clusters. The size of each index buffer, which is used to allocate space for directories. If this number is positive (up to 7F), then it represents clusters per MFT record. If the number is negative (80 to FF), then the size of the file record is 2 raised to the absolute value of this number.
		'a3', 'reserved1',
		'Q',  'volume_serial_number',      # Seems like only the low 32-bits are used
		'L',  'checksum',                  # Boot sector checksum
		
		'a426', 'boot_code',               # Boot loader
		'S',  'signature',                 # Sanity check: always 0xaa55
	])
	SIZEOF_BOOT_PARAMETERS_BLOCK = BOOT_PARAMETERS_BLOCK.size
	
	NTFS_MAGIC = 0xaa55
	
	# BootSect represents a volume boot sector.
	class BootSect
		attr_reader :stream, :bytesPerSector, :sectorsPerCluster, :mediaDescriptor
		attr_reader :totalCapacity, :bytesPerFileRec, :bytesPerIndexRec, :serialNumber
		attr_reader :signature, :bytesPerCluster
		
		attr_accessor :version, :volumeInfo
		
		def initialize(stream)
			raise "MIQ(NTFS::BootSect.initialize) Nil stream" if stream.nil?

			# Buffer stream & get enough data to fill BPB.
			@stream = stream
			buf     = stream.read(SIZEOF_BOOT_PARAMETERS_BLOCK)
			@bpb    = BOOT_PARAMETERS_BLOCK.decode(buf)
			
			# Always check magic number first.
			@signature = @bpb['signature']
			raise "MIQ(NTFS::BootSect.initialize) Boot sector is not NTFS: 0x#{'%04x' % self.signature}" if self.signature != NTFS_MAGIC
	    
			# Get accessor values.
			@bytesPerSector    = @bpb['bytes_per_sector']
			@bytesPerCluster	 = @bpb['sectors_per_cluster'] * @bytesPerSector
			@sectorsPerCluster = @bpb['sectors_per_cluster']
			@mediaDescriptor   = @bpb['media_descriptor']
			@totalCapacity     = @bpb['sectors_per_volume'] * @bytesPerSector
			@bytesPerFileRec   = bytesPerRec(@bpb['clusters_per_mft_record'])
			@bytesPerIndexRec  = bytesPerRec(@bpb['clusters_per_index_record'])
			@serialNumber      = @bpb['volume_serial_number']
			
			# MFTs in-memory
			@sys_mfts    = Hash.new
      @mfts        = LruHash.new(NTFS::DEF_CACHE_SIZE)
		end
	  
		# Convert to string (just return OEM name).
		def to_s
			@bpb['oem_name'].strip
		end
	  
		# NTFS has an interesting shorthand...
		def bytesPerRec(size)
			(size < 0) ? 2 ** size.abs : size * bytesPerCluster
		end
		
		# Return the absolute byte position of the MFT.
		def mftLoc
			@bpb.nil? ? 0 : lcn2abs(@bpb['mft_lcn'])
		end
		
		def fragTable
	    return @fragTable || @rootFragTable
	  end
	  
	  def maxMft
	    return getMaxMft if @fragTable.nil?
			@maxMft ||= getMaxMft
    end
	  
	  def setup
	    @rootFragTable = mftEntry(0).rootAttributeData.data.runSpec
      
	    @sys_mfts.clear
	    @mfts.clear
	    
      # MFT Entry 0 ==> Prepare a fragment table.
			@fragTable  = mftEntry(0).attributeData.data.runSpec   # Get the data runs for the MFT itself.

			# MFT Entry 3 ==> Volume Information
			@volumeInfo = getVolumeInfo()
			@version    = @volumeInfo["version"].to_i
    end
		
	  ################################################################################
	  # From "File System Forensic Analysis" by Brian Carrier
	  #
	  # The $Bitmap file, which is located in MFT entry 6, has a $DATA attribute that is used
	  # to manage the allocation status of clusters.  The bitmap data are organized into 1-byte
	  # values, and the least significant bit of each byte corresponds to the cluster that follows
	  # the cluster that the most significant bit of the previous byte corresponds to.
	  ################################################################################
    def clusterInfo
      return @clusterInfo unless @clusterInfo.nil?

      # MFT Entry 6 ==> BITMAP Information
		  ad = mftEntry(6).attributeData
      data = ad.read(ad.length)
	    ad.rewind

      c = data.unpack("b#{data.length * 8}")[0]
      nclusters = c.length
      on = c.count("1")
      uclusters = on
      fclusters = c.length - on

      return @clusterInfo = {"total" => nclusters, "free" => fclusters, "used" => uclusters}
	  end
		
		# Returns free space on file system in bytes.
  	def freeBytes
  	  clusterInfo["free"] * @bytesPerCluster
	  end
		
		def getVolumeInfo
	    mft = mftEntry(3)
	    vi  = Hash.new

	    if nameAttrib = mft.getFirstAttribute(AT_VOLUME_NAME)
	      vi["name"] = nameAttrib.name
      end
      
      if objectidAttrib = mft.getFirstAttribute(AT_OBJECT_ID)
	      vi["objectId"]      = objectidAttrib.objectId.to_s
	      vi["birthVolumeId"] = objectidAttrib.birthVolumeId.to_s
	      vi["birthObjectId"] = objectidAttrib.birthObjectId.to_s
	      vi["domainId"]      = objectidAttrib.domainId.to_s
      end
      
      if infoAttrib = mft.getFirstAttribute(AT_VOLUME_INFORMATION)
        vi["version"] = infoAttrib.version
        vi["flags"]   = infoAttrib.flags
      end

      return vi
	  end
	  
		def numFrags
			return fragTable.size / 2
		end
		
		# Iterate all run lengths & return how many entries fit.
		def getMaxMft
		  total_clusters = 0
			fragTable.each_slice(2) { |vcn, len| total_clusters += len }
			return total_clusters * @bytesPerCluster / @bytesPerFileRec
		end
		
		def rootDir
		  @rootDir ||= mftEntry(5).indexRoot
	  end
		
		def mftEntry(recordNumber)
		  if recordNumber < 12
		    @sys_mfts[recordNumber] = MftEntry.new(self, recordNumber) unless @sys_mfts.has_key?(recordNumber)
		    return @sys_mfts[recordNumber]
      end

      if @mfts.has_key?(recordNumber)
        mft = @mfts[recordNumber]
        mft.attributeData.rewind unless mft.attributeData.nil?
        return mft
      end
      return @mfts[recordNumber] = MftEntry.new(self, recordNumber)
	  end
		
		# Quick check to see if volume is mountable.
		def isMountable?
			return false if @bpb.nil?
			b  = @bpb['reserved_sectors'] == 0
			b &= @bpb['unused1'] == "\0" * 5
			b &= @bpb['unused2'] == 0
			b &= @bpb['unused4'] == 0
			b &= @bpb['signature'] == 0xaa55
		end
	  
		# Convert a logical cluster number to an absolute byte position.
		def lcn2abs(lcn)
			lcn * bytesPerCluster
		end
	  
		# Convert a virtual cluster number to an absolute byte position.
		def vcn2abs(vcn)
			lcn2abs(vcn)
		end
		
		# Use data run to convert mft record number to byte pos.
		def mftRecToBytePos(recno)
			
			# Return start of mft if rec 0 (no point in the rest of this).
			return mftLoc if recno == 0
			
			# Find which fragment contains the target mft record.
			start = fragTable[0]; last_clusters = 0; target_cluster = recno * @bytesPerFileRec / @bytesPerCluster
			if (recno > @bytesPerCluster / @bytesPerFileRec) && (fragTable.size > 2)
				total_clusters = 0
				fragTable.each_slice(2) do |vcn, len|
					start = vcn #These are now absolute clusters, not offsets.
					total_clusters += len
					break if total_clusters > target_cluster
					last_clusters += len
				end
				# Toss if we haven't found the fragment.
				raise "MIQ(NTFS::BootSect.mftRecToBytePos) Can't find MFT record #{recno} in data run.\ntarget = #{target_cluster}\ntbl = #{fragTable.inspect}" if total_clusters < target_cluster
			end
			
			# Calculate offset in target cluster & final byte position.
			offset = (recno - (last_clusters * @bytesPerCluster / @bytesPerFileRec)) * @bytesPerFileRec
			return start * @bytesPerCluster + offset
		end
		
	end
end # module NTFS
