$:.push("#{File.dirname(__FILE__)}/../../../util")
require 'binary_struct'

module NTFS
		
  # 
  # VOLUME_INFORMATION - Attribute: Volume information (0x70).
  # 
  # NOTE: Always resident.
  # NOTE: Present only in FILE_Volume.
  # NOTE: Windows 2000 uses NTFS 3.0 while Windows NT4 service pack 6a uses NTFS 1.2.
  # 		
		
	ATTRIB_VOLUME_INFORMATION = BinaryStruct.new([
		'Q',  nil,          # No information.
		'C1', 'ver_major',  # File system major version number.
		'C1', 'ver_minor',  # File system minor version number.
		'S',  'flags',      # Volume flags (see VF_ below).
	])
	
	class VolumeInformation
	  
		attr_reader :version, :flags
	  
		VF_IS_DIRTY            = 0x0001
		VF_RESIZE_LOG_FILE     = 0x0002
		VF_UPGRADE_ON_MOUNT    = 0x0004
		VF_MOUNTED_ON_NT4      = 0x0008
		VF_DELETE_USN_UNDERWAY = 0x0010
		VF_REPAIR_OBJECT_ID    = 0x0020
		VF_CHKDSK_UNDERWAY     = 0x4000
		VF_MODIFIED_BY_CHKDSK  = 0x8000
	  
		def initialize(buf)
			raise "MIQ(NTFS::VolumeInformation.initialize) Nil buffer" if buf.nil?
			buf      = buf.read(buf.length) if buf.kind_of?(DataRun)
			@avi     = ATTRIB_VOLUME_INFORMATION.decode(buf)
	    
			# Get accessor data.
			@version = @avi['ver_major'].to_s + "." + @avi['ver_minor'].to_s
			@flags   = @avi['flags']
		end
	  
		def to_s
			@version
		end
	  
		def dump
			out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
			out << "  Major ver: #{@avi['ver_major'].to_i}\n"
			out << "  Minor ver: #{@avi['ver_minor'].to_i}\n"
			out << "  Flags    : 0x#{'%04x' % @flags}\n"
			out << "---\n"
		end
	  
	end
end # module NTFS
