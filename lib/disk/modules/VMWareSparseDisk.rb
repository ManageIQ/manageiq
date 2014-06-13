require 'MiqLargeFile'

$:.push("#{File.dirname(__FILE__)}/../util")

require 'binary_struct'
require 'MiqMemory'

module VMWareSparseDisk

  SPARSE_EXTENT_HEADER = BinaryStruct.new([
    'L', 'magicNumber',
    'L', 'version',
    'L', 'flags',
    'Q', 'capacity',
    'Q', 'grainSize',
    'Q', 'descriptorOffset',
    'Q', 'descriptorSize',
    'L', 'numGTEsPerGT',
    'Q', 'rgdOffset',
    'Q', 'gdOffset',
    'Q', 'overHead',
    'C', 'uncleanShutdown'
  ])
  SIZEOF_SPARSE_EXTENT_HEADER = SPARSE_EXTENT_HEADER.size
  GTE_SIZE = 4
  GDE_SIZE = 4
  
  def d_init
    self.diskType = "VMWare Sparse"
    self.blockSize = 512
		if self.dInfo.mountMode == nil || self.dInfo.mountMode == "r"
			self.dInfo.mountMode = "r"
			fileMode = "r"
		elsif self.dInfo.mountMode == "rw"
			fileMode = "r+"
		else
			raise "Unrecognized mountMode: #{self.dInfo.mountMode}"
		end
		@vmwareSparseDisk_file = MiqLargeFile.open(self.dInfo.fileName, fileMode)
    buf = @vmwareSparseDisk_file.read(SIZEOF_SPARSE_EXTENT_HEADER)
    @sparseHeader = OpenStruct.new(SPARSE_EXTENT_HEADER.decode(buf))
    @grainSize = @sparseHeader.grainSize
    @grainBytes = @grainSize * self.blockSize
    @capacity = @sparseHeader.capacity * self.blockSize
    
		#
    # Seek to start of the grain directory.
    # 
    @vmwareSparseDisk_file.seek(@sparseHeader.gdOffset * self.blockSize, IO::SEEK_SET)
    
    #
    # Read the first grain directory entry to get the offset to the start of
    # the grain tables.
    # 
    buf = @vmwareSparseDisk_file.read(GDE_SIZE)
    @grainTableBase = buf.unpack('L')[0] * self.blockSize
		#dumpGT
  end
  
	def getBase
		return self
	end
  
	def d_read(pos, len, offset = 0)
		gnStart, goStart = grainPos(pos - offset)
		gnEnd, goEnd = grainPos(pos + len - offset)
    
		if gnStart == gnEnd
			grainPos = getGTE(gnStart)
			# Mods for parent link.
			if grainPos == 0
				return MiqMemory.create_zero_buffer(len) if @dInfo.parent == nil
				return @dInfo.parent.d_read(pos, len)
			else
				@vmwareSparseDisk_file.seek(grainPos + goStart, IO::SEEK_SET)
				return @vmwareSparseDisk_file.read(len)
			end
		end
		
		bytesRead = 0
		rv = String.new
		(gnStart..gnEnd).each do |gn|
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
				if @dInfo.parent.nil?
					rv << MiqMemory.create_zero_buffer(l)
				else
					rv << @dInfo.parent.d_read(pos + bytesRead, l)
				end
			else
				@vmwareSparseDisk_file.seek(gp + so, IO::SEEK_SET)
				rv << @vmwareSparseDisk_file.read(l)
			end
			bytesRead += l
		end
		return rv
	end
  
	def d_write(pos, buf, len, offset = 0)
		gnStart, goStart = grainPos(pos - offset)
		gnEnd, goEnd = grainPos(pos + len - offset)
    
		if gnStart == gnEnd
			grainPos = getGTE(gnStart)
			grainPos = allocGrain(gnStart) if grainPos == 0
			@vmwareSparseDisk_file.seek(grainPos + goStart, IO::SEEK_SET)
			return @vmwareSparseDisk_file.write(buf, len)
		end
		
		bytesWritten = 0
		(gnStart..gnEnd).each do |gn|
			so = 0
			l = @grainBytes
      
			if gn == gnStart
				so = goStart
				l = l - so
			end
			if gn == gnEnd
				l = l - (@grainBytes - goEnd)
			end
      
			gp = getGTE(gn)
			gp = allocGrain(gn) if gp == 0
			@vmwareSparseDisk_file.seek(gp + so, IO::SEEK_SET)
			bytesWritten += @vmwareSparseDisk_file.write(buf[bytesWritten, l], l)
		end
		return bytesWritten
	end
	
  def d_close
    @vmwareSparseDisk_file.close
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
    seekGTE(gn)
		gte = @vmwareSparseDisk_file.read(GTE_SIZE).unpack('L')[0]
		return gte * self.blockSize
  end
	
	def allocGrain(gn)
		sector = findFreeSector; byte = gn * @grainBytes
		buf = @dInfo.parent.nil? ? MiqMemory.create_zero_buffer(@grainBytes) : @dInfo.parent.d_read(byte, @grainBytes)
		seekGTE(gn)
		@vmwareSparseDisk_file.write([sector].pack('L'), GTE_SIZE)
		@vmwareSparseDisk_file.seek(sector * self.blockSize, IO::SEEK_SET)
		@vmwareSparseDisk_file.write(buf, @grainBytes)
		return sector * self.blockSize
	end
	
	def seekGTE(gn)
    gteOffset = @grainTableBase + (gn * GTE_SIZE)
    @vmwareSparseDisk_file.seek(gteOffset, IO::SEEK_SET)
	end
	
	def findFreeSector
		if @freeSector.nil?
			numGrains = @sparseHeader.capacity / @grainSize
			@vmwareSparseDisk_file.seek(@grainTableBase, IO::SEEK_SET)
			@freeSector = 0
			numGrains.times do |i|
				last = @vmwareSparseDisk_file.read(GTE_SIZE).unpack('L')[0]
				@freeSector = last if last > @freeSector
			end
		end
		@freeSector += @grainSize
		raise "Disk full." if @freeSector * self.blockSize > @capacity
		return @freeSector
	end
end
