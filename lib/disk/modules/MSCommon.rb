$:.push("#{File.dirname(__FILE__)}")
require 'MiqLargeFile'

$:.push("#{File.dirname(__FILE__)}/../../util")
require 'miq-unicode'
require 'binary_struct'
require 'MiqMemory'


module MSCommon
	
	# NOTE: All values are stored in network byte order.
	
	FOOTER = BinaryStruct.new([
		'a8',		'cookie',						# Always 'conectix'.
		'N',		'features',					# Should be 2 or 3 (bit 0 is temp disk).
		'N',		'version',					# Major/Minor file format version.
		'N',		'data_offset_hi',		# Offset from beginning of file to next data struct (dyn & diff only, 0xffffffff for fixed).
		'N',		'data_offset_lo',
		'N',		'time_stamp',				# Create time (sec since Jan 1 2000 12:00 AM in GMT).
		'a4',		'creator_app',			# Virtual PC = 'vpc ', Virtual Server = 'vs  '.
		'N',		'creator_ver',			# Major/Minor ver of creator app.
		'N',		'creator_host',			# Creator host: Windows = 0x5769326b ('Wi2k'); Macintosh = 0x4d616320 ('Mac ').
		'N',		'original_size_hi',	# Original size of disk.
		'N',		'original_size_lo',
		'N',		'current_size_hi',	# Current size of the disk.
		'N',		'current_size_lo',
		'N',		'disk_geometry',		# CHS (byte sizes 2, 1, 1) values for disk.
		'N',		'disk_type',				# Disk subtype (Fixed, Dynamic or Differencing).
		'N',		'checksum',					# One's compliment of sum of struct minus this field.
		'a16',	'unique_id',				# UUID.
		'C',		'saved_state',			# If 1, system is in 'saved state'.
	])

	HEADER = BinaryStruct.new([
		'a8',		'cookie',						# Always 'cxsparse'.
		'Q',		'data_offset',			# Unused, should be 0xffffffff.
		'N',		'table_offset_hi',	# Byte offset to the Block Allocation Table.
		'N',		'table_offset_lo',
		'N',		'header_ver',				# Major/Minor header version.
		'N',		'max_tbl_ent',			# Max entries in the BAT.
		'N',		'block_size',				# Size of data section of a block, default 2M (0x00200000).
		'N',		'checksum',					# One's compliment sum of all fields minus this one.
		'a16',	'parent_uuid',			# Parent disk UUID (for differencing disk only).
		'N',		'parent_tstamp',		# MTime of parent disk (sec since Jan 1 2000 12:00 AM in GMT).
		'N',		'reserved1',				# reserved, should be 0.
		'a512',	'parent_uname',			# Parent disk filename in UNICODE (UTF-16).
		'a24',	'parent_loc1',			# Parent locator entries.
		'a24',	'parent_loc2',
		'a24',	'parent_loc3',
		'a24',	'parent_loc4',
		'a24',	'parent_loc5',
		'a24',	'parent_loc6',
		'a24',	'parent_loc7',
		'a24',	'parent_loc8',
	])
	
	PARENT_LOCATOR = BinaryStruct.new([
		'a4',	'platform_code',	# Platform specific format used for locator.
		'N',	'data_space',			# Number of sectors used to store locator.
		'N',	'data_length',		# Byte length of locator.
		'N',	'reserved1',			# Must be zero.
		'N',	'data_offset_hi',	# Absolute byte offset of locator.
		'N',	'data_offset_lo',
	])
	
	BAE_SIZE = 4
	SECTOR_LENGTH = 512
	FOOTER_LENGTH = 512
	HEADER_LOCATION = 512
	BLOCK_NOT_ALLOCATED = 0xffffffff
	SUPPORTED_HEADER_VERSION = 0x00010000
	
	def MSCommon.d_init_common(dInfo, file)
		@dInfo = dInfo
		@blockSize = SECTOR_LENGTH
		@file = file
		
		# Get file,  footer & header, do footer verification.
		@footer = getFooter(@file)
		@header = getHeader(@footer)
		verifyFooterCopy(@footer)
		
		# Verify footer copy.
		
		# Verify format version number (must be 0x00010000).
		raise "Incompatible header version: 0x#{'%04x' % @header['header_ver']}" if @header['header_ver'] != SUPPORTED_HEADER_VERSION
		
		# Calc sectors per block, bytes in block sector bitmap & BAT loc.
		@secPerBlock = @header['block_size'] / @blockSize
		@blockSectorBitmapByteCount = @secPerBlock / 8
		if (bd = @blockSectorBitmapByteCount % 512) != 0
			@blockSectorBitmapByteCount = @blockSectorBitmapByteCount + 512 - bd
		end
		@batBase = getHiLo(@header, "table_offset")
	end
	
  def MSCommon.d_read_common(pos, len, parent = nil)
    # Get starting & ending block, sector & byte offset of read.
		blockStart, sectorStart, byteOffsetStart = blockPos(pos)
    blockEnd,   sectorEnd,   byteOffsetEnd   = blockPos(pos + len - 1)
        
		# Loop on blocks (2M entities of storage).
		buf = ""
    (blockStart..blockEnd).each do |blockNum|
      
			# Loop on sectors (512 byte entities of storage).
			secStart = (blockNum == blockStart) ? sectorStart : 0
			secEnd   = (blockNum == blockEnd  ) ? sectorEnd   : @secPerBlock - 1
			(secStart..secEnd).each do |secNum|
				
				# If STARTING, need to skip to where data is
				if (blockStart == blockEnd) and (sectorStart == sectorEnd)
					byteOffset = byteOffsetStart
					thisLen    = len
				elsif (blockNum == blockStart) && (secNum == sectorStart)
					byteOffset = byteOffsetStart
					thisLen    = @blockSize - byteOffset
				# If ENDING, need to account for short read
				elsif (blockNum == blockEnd) && (secNum == sectorEnd)
    			byteOffset = 0
				  thisLen    = len - buf.length
				  raise "Internal Error: Calculated read more than sector: #{thisLen}" if thisLen > @blockSize
  				# Read ENTIRE Sector in all other cases
			  else
    			byteOffset = 0
  				thisLen   = @blockSize
			  end
				
				# If the allocation status of this sector is 0 return zeros.
				allocStat = getAllocStatus(blockNum, secNum)
				if allocStat == false
					if parent == nil
  					buf << MiqMemory.create_zero_buffer(thisLen) 
  				else
					  buf << parent.d_read(pos + buf.length, thisLen, mark_dirty)
				  end
				else
					@file.seek(getAbsSectorLoc(blockNum, secNum) + byteOffset, IO::SEEK_SET)
					buf << @file.read(thisLen)
				end
			end
    end
    return buf
  end
	
	def MSCommon.d_write_common(pos, buf, len, parent = nil)
    # Get starting & ending block, sector & byte offset of read.
		blockStart, sectorStart, byteOffsetStart = blockPos(pos)
    blockEnd,   sectorEnd,   byteOffsetEnd   = blockPos(pos + len - 1)
		
		# Loop on blocks (2M entities of storage).
    bytesWritten = 0
		(blockStart..blockEnd).each do |blockNum|
      
			# Loop on sectors (512 byte entities of storage).
			secStart = (blockNum == blockStart) ? sectorStart : 0
			secEnd   = (blockNum == blockEnd  ) ? sectorEnd   : @secPerBlock - 1
			(secStart..secEnd).each do |secNum|
				
				# If STARTING, need to skip to where data is
				if (blockStart == blockEnd) and (sectorStart == sectorEnd)
					byteOffset = byteOffsetStart
					thisLen    = len
				elsif (blockNum == blockStart) && (secNum == sectorStart)
					byteOffset = byteOffsetStart
					thisLen    = @blockSize - byteOffset
					# If ENDING, need to account for short read
				elsif (blockNum == blockEnd) && (secNum == sectorEnd)
    			byteOffset = 0
				  thisLen    = len - bytesWritten
				  raise "Internal Error: Calculated read more than sector: #{thisLen}" if thisLen > @blockSize
  				# Read ENTIRE Sector in all other cases
			  else
    			byteOffset = 0
  				thisLen   = @blockSize
			  end
				
				# If the allocation status of this sector is 0 then allocate it.
				allocStat = getAllocStatus(blockNum, secNum)
				allocSector(blockNum, secNum, pos + bytesWritten, parent) if allocStat == false
				@file.seek(getAbsSectorLoc(blockNum, secNum) + byteOffset, IO::SEEK_SET)
				bytesWritten += @file.write(buf[bytesWritten, thisLen], thisLen)
			end
    end
    return bytesWritten
		end
	
	# Disk size in sectors.
	def MSCommon.d_size_common
		return getHiLo(@footer, "current_size") / @blockSize
	end
	
	def MSCommon.getHiLo(hash, member)
		return (hash["#{member}_hi"] << 32) + hash["#{member}_lo"]
	end
	
	# Needed by diff disk.
	def MSCommon.header
		return @header
	end
	
	def MSCommon.getFooter(file, skip_check = false)
		# NOTE: Spec says that if checksum fails use the copy in the header.
		#       If that fails then the disk is corrupt.
	  file.seek(file.size - FOOTER_LENGTH, IO::SEEK_SET)
		@footerBuf = file.read(FOOTER_LENGTH)
		footer = FOOTER.decode(@footerBuf)
		if not skip_check
			footerCsum = checksum(@footerBuf, 64)
			raise "Footer checksum doesn't match: got 0x#{'%04x' % footerCsum}, s/b 0x#{'%04x' % @footer['checksum']}" if footerCsum != footer['checksum']
		end
		return footer
	end
	
	private
	
	def MSCommon.getHeader(footer, skip_check = false)
		hdrLoc = getHiLo(footer, "data_offset")
		hdrSiz = HEADER.size
		puts "VHD Header is mislocated: 0x#{'%04x' % hdrLoc} (s/b 0x0200)" if hdrLoc != HEADER_LOCATION and not skip_check
		@file.seek(hdrLoc, IO::SEEK_SET)
		buf = @file.read(hdrSiz)
		header = HEADER.decode(buf)
		if not skip_check
			headerCsum = checksum(buf, 36)
			raise "Header checksum doesn't match: got 0x#{'%04x' % headerCsum}, s/b 0x#{'%04x' % @header['checksum']}" if headerCsum != header['checksum']
		end
		return header
	end
	
	def MSCommon.verifyFooterCopy(footer)
		hdrLoc = getHiLo(footer, "data_offset")
		@file.seek(hdrLoc - FOOTER_LENGTH, IO::SEEK_SET)
		footer_copy = FOOTER.decode(@file.read(FOOTER_LENGTH))
		puts "Footer copy does not match header." if footer_copy != @footer
	end
	
	def MSCommon.blockPos(pos)
    rawSectorNumber, byteOffset = pos.divmod(@blockSize)
    blockNumber, secInBlock = rawSectorNumber.divmod(@secPerBlock)
    return blockNumber, secInBlock, byteOffset
	end
  
  def MSCommon.getBAE(blockNumber)
    seekBAE(blockNumber)
    return @file.read(BAE_SIZE).unpack('N')[0]
  end
	
	def MSCommon.putBAE(blockNum, bae)
		seekBAE(blockNum)
		@file.write([bae].pack('N'), BAE_SIZE)
	end
	
	def MSCommon.seekBAE(blockNum)
		batOffset = blockNum * BAE_SIZE + @batBase
		@file.seek(batOffset, IO::SEEK_SET)
	end
	
	def MSCommon.getAllocStatus(blockNum, sectorNum)
		sectorMask = seekAllocStatus(blockNum, sectorNum)
		return false if sectorMask == BLOCK_NOT_ALLOCATED
		sectorBitmap = @file.read(1).unpack('C')[0]
		return sectorBitmap & sectorMask == sectorMask
	end
  
	def MSCommon.setAllocStatus(blockNum, sectorNum)
		sectorMask = seekAllocStatus(blockNum, sectorNum)
		sectorBitmap = @file.read(1).unpack('C')[0]
		sectorBitmap |= sectorMask
		@file.seek(-1, IO::SEEK_CUR)
		@file.write([sectorBitmap].pack('C'), 1)
	end
	
	def MSCommon.seekAllocStatus(blockNum, sectorNum)
		sectorByte, bitOffset = sectorNum.divmod(8)
		bae = getBAE(blockNum)
		return bae if bae == BLOCK_NOT_ALLOCATED
		@file.seek(bae * @blockSize + sectorByte, IO::SEEK_SET)
		return 0x80 >> bitOffset
	end
	
	def MSCommon.getAbsSectorLoc(blockNum, sectorNum)
		return getBAE(blockNum) * @blockSize + sectorNum * @blockSize + @blockSectorBitmapByteCount
	end
	
	def MSCommon.allocSector(blockNum, sectorNum, pos, parent)
		allocBlock(blockNum) if getBAE(blockNum) == BLOCK_NOT_ALLOCATED
		if parent.nil?
			buf = MiqMemory.create_zero_buffer(@blockSize)
		else
			sector = pos.divmod(@blockSize)[0]
			buf = parent.d_read(sector, @blockSize)
		end
		setAllocStatus(blockNum, sectorNum)
		@file.seek(getAbsSectorLoc(blockNum, sectorNum), IO::SEEK_SET)
		@file.write(buf, buf.size)
	end
	
	def MSCommon.allocBlock(blockNum)
		# Alloc block.
		pos = @file.size - FOOTER_LENGTH
		sector = findFreeSector
		putBAE(blockNum, sector)
		# Write sector alloc bitmap.
		bmp = MiqMemory.create_zero_buffer(@blockSectorBitmapByteCount)
		@file.seek(sector * @blockSize, IO::SEEK_SET)
		@file.write(bmp, bmp.size)
		# Footer has to move. Total size is 2048 + size of data blocks.
		pos += @secPerBlock * @blockSize
		@file.seek(pos, IO::SEEK_SET)
		@file.write(@footerBuf, @footerBuf.size)
	end
	
	def MSCommon.findFreeSector
		# Find a free disk sector with which to start a new block.
		if @freeSector.nil?
			seekBAE(0); ents = @header['max_tbl_ent']
			baes = @file.read(ents * BAE_SIZE).unpack("N#{ents}")
			baes.delete(BLOCK_NOT_ALLOCATED)
			raise "Disk full." if baes.size == @header['max_tbl_ent']
			@freeSector = baes.max
		end
		@freeSector += @secPerBlock
		raise "Disk full." if @freeSector > self.d_size_common / @blockSize
		return @freeSector
	end
	
	def MSCommon.checksum(buf, skip_offset)
		csum = 0
		0.upto(buf.size - 1) {|i|
			next if i >= skip_offset && i < skip_offset + 4
			csum += buf[i]
		}
		# GRRRRR - convert to actual 32-bits.
		return [~csum].pack('L').unpack('L')[0]
	end
end #module
