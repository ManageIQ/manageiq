# encoding: US-ASCII
require 'MiqLargeFile'
require 'MSCommon'

module MSVSDiskProbe
	
	MS_MAGIC			= "conectix"

	TYPE_FIXED		= 2
	TYPE_DYNAMIC	= 3
	TYPE_DIFF			= 4

	MOD_FIXED			= "MSVSFixedDisk"
	MOD_DYNAMIC		= "MSVSDynamicDisk"
	MOD_DIFF			= "MSVSDiffDisk"

	def MSVSDiskProbe.probe(ostruct)
	    return nil if !ostruct.fileName
		# If file not VHD then not Microsoft.
		# Allow ".miq" also.
		ext = File.extname(ostruct.fileName).downcase
		return nil if ext != ".vhd" && ext != ".avhd" && ext != ".miq"
		
		# Get (assumed) footer.
		msDisk_file = MiqLargeFile.open(ostruct.fileName, "rb")
	  footer = MSCommon.getFooter(msDisk_file, true)
	  msDisk_file.close
		msDisk_file = nil
		
		# Check for MS disk.
		return nil if footer['cookie'] != MS_MAGIC
		
		# Return module name to handle type.
		case footer['disk_type']
			when TYPE_FIXED
				return MOD_FIXED
			when TYPE_DYNAMIC
				return MOD_DYNAMIC
			when TYPE_DIFF
				return MOD_DIFF
			else
				raise "Unsupported MS disk: #{footer['disk_type']}"
		end
	end
end
