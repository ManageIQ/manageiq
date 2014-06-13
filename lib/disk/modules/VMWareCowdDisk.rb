require 'MiqLargeFile'

$:.push("#{File.dirname(__FILE__)}/../util")
require 'binary_struct'
require 'MiqMemory'


module VMWareCowdDisk

	COWD_EXTENT_HEADER = BinaryStruct.new([
		'L', 'magicNumber',
		'L', 'version',
		'L', 'flags',
		'L', 'numSectors',
		'L', 'grainSize',
		'L', 'gdOffset',
		'L', 'numGDEntries',
		'L', 'freeSector',
	])
	
	SIZEOF_COWD_EXTENT_HEADER = COWD_EXTENT_HEADER.size
	GTE_SIZE = 4
	GDE_SIZE = 4
	GDE_COVERAGE = 2097152
	ENTRIES_PER_TABLE = 4096
	GT_SECTORS = 32
	
	def d_init
		self.diskType = "VMWare CopyOnWrite"
		self.blockSize = 512
    if self.dInfo.mountMode == nil || self.dInfo.mountMode == "r"
      self.dInfo.mountMode = "r"
      fileMode = "r"
    elsif self.dInfo.mountMode == "rw"
      fileMode = "r+"
    else
      raise "Unrecognized mountMode: #{self.dInfo.mountMode}"
    end
    @dParent = @dInfo.parent

		@vmwareCowDisk_file = MiqLargeFile.open(self.dInfo.fileName, fileMode)
		buf = @vmwareCowDisk_file.read(SIZEOF_COWD_EXTENT_HEADER)
		@EsxSparseHeader = OpenStruct.new(COWD_EXTENT_HEADER.decode(buf))
		
		@grainSize = @EsxSparseHeader.grainSize
		@grainBytes = @grainSize * self.blockSize
		@capacity = @EsxSparseHeader.numSectors * self.blockSize
		@gdStart = @EsxSparseHeader.gdOffset * self.blockSize
		@gdSize = @EsxSparseHeader.numGDEntries * GDE_SIZE
	end
	
	def getBase
	    return self
	end
	
	def d_read(pos, len, offset = 0)
		gnStart, goStart = grainPos(pos)
		gnEnd, goEnd = grainPos(pos+len )
		
		if gnStart == gnEnd
			grainPos = getGTE(gnStart)
			if grainPos == 0
				return @dParent ? @dParent.d_read(pos, len) : MiqMemory.create_zero_buffer(len)
			else
				@vmwareCowDisk_file.seek(grainPos+goStart, IO::SEEK_SET)
				return @vmwareCowDisk_file.read(len)
			end
		end

		bytesRead = 0
		rv = String.new
		gnStart.upto(gnEnd) do |gn|
			so = 0
			l = @grainBytes
      
			if gn == gnStart
				so = goStart
				l = l - so
			end
			l -= (@grainBytes - goEnd) if gn == gnEnd
			
			gp = getGTE(gn)
			# Mods for parent link.
			if gp == 0
        rv << (@dParent ? @dParent.d_read(pos + bytesRead, l) : MiqMemory.create_zero_buffer(l))
			else
				@vmwareCowDisk_file.seek(gp+so, IO::SEEK_SET)
				rv << @vmwareCowDisk_file.read(l)
			end
			bytesRead += l
		end
		return rv
	end
	
	def d_write(pos, buf, len, offset = 0)
		gnStart, goStart = grainPos(pos)
		gnEnd, goEnd = grainPos(pos+len )
		
		if gnStart == gnEnd
			grainPos = getGTE(gnStart)
			grainPos = allocGrain(gnStart) if grainPos == 0
			@vmwareCowDisk_file.seek(grainPos+goStart, IO::SEEK_SET)
			return @vmwareCowDisk_file.write(buf, len)
		end
		
		bytesWritten = 0
		gnStart.upto(gnEnd) do |gn|
			so = 0
			l = @grainBytes
      
			if gn == gnStart
				so = goStart
				l = l - so
			end
			l -= (@grainBytes - goEnd) if gn == gnEnd
			
			gp = getGTE(gn)
			gp = allocGrain(gn) if gp == 0
			raise "Disk is full" if gp == -1
			@vmwareCowDisk_file.seek(gp+so, IO::SEEK_SET)
			bytesWritten += @vmwareCowDisk_file.write(buf[bytesWritten, l], l)
		end
		return bytesWritten
	end
	
	def d_close
		@vmwareCowDisk_file.close
	end
	
	# Disk size in sectors.
	def d_size
		@capacity / @blockSize
	end
	
	private
	
	def grainPos(pos)
		gn = pos/@grainBytes
		go = pos - (gn * @grainBytes)
		return gn, go
	end
    
	def getGTE(gn)
		return 0 if seekGTE(gn) == -1
		gte = @vmwareCowDisk_file.read(GTE_SIZE).unpack('L')[0]
		return gte * self.blockSize
	end
	
	def putGTE(gn, sector)
		seekGTE(gn)
		@vmwareCowDisk_file.write([sector].pack('L'), GTE_SIZE)
	end
		
	def allocGrain(gn)
		allocGT(gn) if getGDE(gn) == 0
		freeSector = @EsxSparseHeader.freeSector
		raise "Disk full." if freeSector + @grainSize > @EsxSparseHeader.numSectors
		thisGrain = freeSector * self.blockSize
		putGTE(gn, freeSector)
		freeSector += @grainSize
		updateFreeSector(freeSector)
		copyOnWrite(gn) if @dParent
		return thisGrain
	end
	
	def seekGTE(gn)
		seekGDE(gn)
		gde = @vmwareCowDisk_file.read(GDE_SIZE).unpack('L')[0] * self.blockSize
		return -1 if gde == 0
		@vmwareCowDisk_file.seek(gde + gn.modulo(ENTRIES_PER_TABLE) * GTE_SIZE, IO::SEEK_SET)
	end
	
	def getGDE(gn)
		seekGDE(gn)
		return @vmwareCowDisk_file.read(GDE_SIZE).unpack('L')[0]
	end
	
	def putGDE(gn, sector)
		seekGDE(gn)
		return @vmwareCowDisk_file.write([sector].pack('L'), GDE_SIZE)
	end
	
	def seekGDE(gn)
		grainDirEntOfs = (gn * @grainBytes).divmod(GDE_COVERAGE)[0]
		@vmwareCowDisk_file.seek(@gdStart + grainDirEntOfs * GDE_SIZE, IO::SEEK_SET)
	end
	
	def allocGT(gn)
		freeSector = @EsxSparseHeader.freeSector
		raise "Disk full." if freeSector + GT_SECTORS > @EsxSparseHeader.numSectors
		putGDE(gn, freeSector)
		freeSector += GT_SECTORS
		gtSize = ENTRIES_PER_TABLE * GTE_SIZE
		gt = MiqMemory.create_zero_buffer(gtSize)
		@vmwareCowDisk_file.seek(freeSector * self.blockSize, IO::SEEK_SET)
		@vmwareCowDisk_file.write(gt, gtSize)
		updateFreeSector(freeSector)
	end
	
	def updateFreeSector(freeSector)
		@EsxSparseHeader.freeSector = freeSector
		@vmwareCowDisk_file.seek(SIZEOF_COWD_EXTENT_HEADER - 4, IO::SEEK_SET)
		@vmwareCowDisk_file.write([freeSector].pack('L'), 4)
	end
	
	def copyOnWrite(gn)
		buf = @dParent.d_read(gn * self.blockSize, @grainBytes)
		@vmwareCowDisk_file.seek(gn * self.blockSize, IO::SEEK_SET)
		@vmwareCowDisk_file.write(buf, @grainBytes)
	end
	
end
