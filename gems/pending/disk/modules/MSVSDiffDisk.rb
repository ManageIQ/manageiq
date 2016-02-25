# encoding: US-ASCII

require 'disk/modules/MSCommon'

module MSVSDiffDisk
  def d_init
    self.diskType = "MSVS Differencing"
    self.blockSize = MSCommon::SECTOR_LENGTH
    if dInfo.mountMode.nil? || dInfo.mountMode == "r"
      dInfo.mountMode = "r"
      fileMode = "r"
    elsif dInfo.mountMode == "rw"
      fileMode = "r+"
    else
      raise "Unrecognized mountMode: #{dInfo.mountMode}"
    end
    if dInfo.hyperv_connection
      @hyperv_connection = dInfo.hyperv_connection
      @ms_disk_file      = MSCommon.connect_to_hyperv(dInfo)
    else
      @hyperv_connection = nil
      @ms_disk_file      = MiqLargeFile.open(dInfo.fileName, fileMode) unless dInfo.baseOnly
    end
    MSCommon.d_init_common(dInfo, @ms_disk_file) unless dInfo.baseOnly

    # Get parent locators.
    @locators = []
    1.upto(8) do|idx|
      @locators << MSCommon::PARENT_LOCATOR.decode(MSCommon.header["parent_loc#{idx}"])
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
      # getParentPathWin(locator)

      when "W2ku"
        # Absolute path - this is the one.
        getParentPathWin(locator)
        getParent(locator)

      when "Mac "
      #
      # TODO: need details on Mac Alias Blob.
      #
      # getParentPathMac(locator)

      when "MacX"
        # Is platform spanning even something we should do?
        # NOTE: Oleg says don't worry about it for the present (03/14/2007).
        getParentPathMacX(locator)
        getParent(locator)

      end
      # raise "No compatible parent locator found" if @parent == nil
    end
  end

  def getBase
    @parent || self
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
    @ms_disk_file.close
  end

  def d_size
    total = 0
    total = @parent.d_size if @parent
    total += @ms_disk_file.size
    total
  end

  # /////////////////////////////////////////////////////////////////////////
  # // Helpers.

  private

  def getParent(locator)
    if locator.key?('fileName')
      @parent_ostruct                   = OpenStruct.new
      @parent_ostruct.fileName          = locator['fileName']
      @parent_ostruct.driveType         = dInfo.driveType
      @parent_ostruct.hyperv_connection = @hyperv_connection unless @hyperv_connection.nil?
      @parent                           = MiqDisk.getDisk(@parent_ostruct)
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
    @ms_disk_file.seek(MSCommon.getHiLo(locator, "data_offset"), IO::SEEK_SET)
    @ms_disk_file.read(locator['data_length'])
  end
end
