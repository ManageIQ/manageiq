require 'sys-uname'
require 'util/miq-system'

if Sys::Platform::IMPL == :linux
  if MiqSystem.arch == :x86_64
    require 'linux_block_device'
    require 'disk/modules/RawBlockIO'
  end
elsif Sys::Platform::OS == :windows
  require 'disk/modules/MiqLargeFileWin32'
end

module MiqLargeFile
  def self.open(file_name, flags)
    case Sys::Platform::OS
    when :windows
      return(MiqLargeFileWin32.new(file_name, flags))
    when :unix
      if Sys::Platform::IMPL == :linux
        return(RawBlockIO.new(file_name, flags)) if MiqLargeFileStat.new(file_name).blockdev?
      end
      return(MiqLargeFileOther.new(file_name, flags))
    else
      return(MiqLargeFileOther.new(file_name, flags))
    end
  end

  def self.size(file_name)
    case Sys::Platform::OS
    when :windows
      # The win32/file require is needed to support +2GB file sizes
      require 'win32/file'
      File.size(file_name)
    else
      f = open(file_name, "r")
      s = f.size
      f.close
      return s
    end
  end

  # For camcorder interposition.
  class MiqLargeFileStat
    def initialize(file_name)
      @file_name = file_name
    end

    def blockdev?
      File.stat(@file_name).blockdev?
    end
  end

  class MiqLargeFileOther < File
    def write(buf, _len)
      super(buf)
    end

    def size
      return stat.size unless stat.blockdev?
      LinuxBlockDevice.size(fileno)
    end
  end
end
