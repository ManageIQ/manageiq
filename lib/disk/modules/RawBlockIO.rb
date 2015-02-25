
$:.push("#{File.dirname(__FILE__)}")

require 'io/extra'
require 'MiqBlockDevOps'

class RawBlockIO

  MIN_SECTORS_TO_CACHE = 64

  def initialize(filename, mode="r")
    # We must start with a block special file
    raise "RawBlockIO: #{filename} is not a blockSpecial file" unless File.stat(filename).ftype == 'blockSpecial'

    @rawDisk_file = File.open(filename, mode)

    @blockSize      = 512
    @filename       = filename
    @mode           = mode
    @size           = MiqBlockDevOps.blkgetsize64(@rawDisk_file.fileno)
    @sizeInBlocks   = @size / @blockSize
    @startByteAddr  = 0
    @endByteAddr    = @size - 1
    @lbaEnd         = @sizeInBlocks - 1
    @seekPos        = 0

    # Enable directio (raw)
    @rawDisk_file.directio = IO::DIRECTIO_ON

    $log.debug "RawBlockIO: opened #{@filename}, size = #{@size} (#{@sizeInBlocks} blocks)"
  end

  def read(len)
    return nil if @seekPos >= @endByteAddr
    len = @endByteAddr - @seekPos if (@seekPos + len) > @endByteAddr
      
    startSector, startOffset = @seekPos.divmod(@blockSize)
    endSector = (@seekPos+len-1)/@blockSize
    numSector = endSector - startSector + 1
            
    rBuf = breadCached(startSector, numSector)
    @seekPos += len

    return rBuf[startOffset, len]
  end

  def write(buf, len)
    return nil if @seekPos >= @endByteAddr
    len = @endByteAddr - @seekPos if (@seekPos + len) > @endByteAddr
      
    startSector, startOffset = @seekPos.divmod(@blockSize)
    endSector = (@seekPos+len-1)/@blockSize
    numSector = endSector - startSector + 1

    rBuf = bread(startSector, numSector)
    rBuf[startOffset, len] = buf[0, len]

    bwrite(startSector, numSector, rBuf)
    @seekPos += len

    return len
  end

  def seek(amt, whence=IO::SEEK_SET)
    case whence
      when IO::SEEK_CUR
        @seekPos += amt
      when IO::SEEK_END
        @seekPos = @endByteAddr + amt
      when IO::SEEK_SET
        @seekPos = amt + @startByteAddr
      else
    end
    return @seekPos
  end

  def size
    @size
  end

  def close
    @rawDisk_file.close
  end

  def bread(startSector, numSectors)
    # $log.debug "RawBlockIO.bread: startSector = #{startSector}, numSectors = #{numSectors}, @lbaEnd = #{@lbaEnd}"
    return nil if startSector > @lbaEnd
    numSectors = @sizeInBlocks - startSector if (startSector + numSectors) > @sizeInBlocks
      
    @rawDisk_file.sysseek(startSector * @blockSize, IO::SEEK_SET)
    @rawDisk_file.sysread(numSectors * @blockSize, @cache)
  end

  def bwrite(startSector, numSectors, buf)
    return nil if startSector > @lbaEnd
    numSectors = @sizeInBlocks - startSector if (startSector + numSectors) > @sizeInBlocks

    @rawDisk_file.sysseek(startSector * @blockSize, IO::SEEK_SET)
    @rawDisk_file.syswrite(buf, numSectors * @blockSize)
  end

  def breadCached(startSector, numSectors)
    # $log.debug "RawBlockIO.breadCached: startSector = #{startSector}, numSectors = #{numSectors}"
    if @cacheRange.nil? || !@cacheRange.include?(startSector) || !@cacheRange.include?(startSector + numSectors - 1)
      sectorsToRead = [MIN_SECTORS_TO_CACHE, numSectors].max
      @cache        = MiqBlockDevOps.aligned_str_buf(@blockSize, @blockSize * sectorsToRead)
      bread(startSector, sectorsToRead)
      sectorsRead   = @cache.length / @blockSize
      endSector     = startSector + sectorsRead - 1
      @cacheRange   = Range.new(startSector, endSector)
    end
      
    sectorOffset = startSector  - @cacheRange.first
    bufferOffset = sectorOffset * @blockSize
    length       = numSectors   * @blockSize
    # $log.debug "RawBlockIO.breadCached: bufferOffset = #{bufferOffset}, length = #{length}"
      
    return @cache[bufferOffset, length]
  end

end
