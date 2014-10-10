# encoding: US-ASCII

require 'MSCommon'

module MSVSDiffDisk
	
	def d_init
		self.diskType = "MSVS Differencing"
		self.blockSize = MSCommon::SECTOR_LENGTH
		if self.dInfo.mountMode == nil || self.dInfo.mountMode == "r"
			self.dInfo.mountMode = "r"
			fileMode = "r"
		elsif self.dInfo.mountMode == "rw"
			fileMode = "r+"
		else
			raise "Unrecognized mountMode: #{self.dInfo.mountMode}"
		end
		@msDisk_file = MiqLargeFile.open(@dInfo.fileName, fileMode) unless @dInfo.baseOnly
		MSCommon.d_init_common(@dInfo, @msDisk_file) unless @dInfo.baseOnly
		
		# Get parent locators.
		@locators = []
		1.upto(8) {|idx|
			@locators << MSCommon::PARENT_LOCATOR.decode(MSCommon.header["parent_loc#{idx.to_s}"])
			next if @locators[idx - 1]['platform_code'] == "\000\000\000\000"
			locator = @locators[idx - 1]
			case locator['platform_code']
				when "Wi2r"
					# Deprecated (no information on format)
				
				when "Wi2k"
					# Deprecated (no information on format)
				
				when "W2ru"
					# Relative path. Would much rather have absolute path.
					# NOTE: Absolute path always accompanies relative path.
					#getParentPathWin(locator)
				
				when "W2ku"
					# Absolute path - this is the one.
					getParentPathWin(locator)
					getParent(locator)
				
				when "Mac "
					#
					# TODO: need details on Mac Alias Blob.
					#
					#getParentPathMac(locator)
				
				when "MacX"
					# Is platform spanning even something we should do?
					# NOTE: Oleg says don't worry about it for the present (03/14/2007).
					getParentPathMacX(locator)
					getParent(locator)
			
			end
			#raise "No compatible parent locator found" if @parent == nil
		}
	end
	
	def getBase
	    return @parent || self
	end
  
	# /////////////////////////////////////////////////////////////////////////
	# Implementation.
	
  def d_read(pos, len)
		MSCommon.d_read_common(pos, len, @parent)
  end
  
	def d_write(pos, buf, len)
		MSCommon.d_write_common(pos, buf, len, @parent)
	end
	
	def d_close
		@parent.close if @parent
		@msDisk_file.close
	end
  
	def d_size
		total = 0
		total = @parent.d_size if @parent
		total += @msDisk_file.size
		return total
	end
	
	# /////////////////////////////////////////////////////////////////////////
	# // Helpers.
	private
	
	def getParent(locator)
		if locator.has_key?('fileName')
			@parentOstruct = OpenStruct.new
			@parentOstruct.fileName = locator['fileName']
			@parent = MiqDisk.getDisk(@parentOstruct)
		end
	end
	
	def getParentPathWin(locator)
		buf = getPathData(locator)
		locator['fileName'] = buf.UnicodeToUtf8!
	end
	
	def getParentPathMac(locator)
		buf = getPathData(locator)
		# how do I decode a Mac alias blob?
	end
	
	def getParentPathMacX(locator)
		buf = getPathData(locator)
		# this is a standard UTF-8 URL.
		locator['fileName'] = buf
	end
	
	def getPathData(locator)
		@msDisk_file.seek(MSCommon.getHiLo(locator, "data_offset"), IO::SEEK_SET)
		return @msDisk_file.read(locator['data_length'])
	end
	
end
