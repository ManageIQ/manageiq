require 'platform'
require 'util/miq-system'

if Platform::IMPL == :linux
	if MiqSystem.arch == :x86
		require 'large_file_linux'
	elsif MiqSystem.arch == :x86_64
		require 'linux_block_device'
		require 'disk/modules/RawBlockIO'
	end
elsif Platform::OS == :win32
	require 'disk/modules/MiqLargeFileWin32'
end

module MiqLargeFile
	def self.open(file_name, flags)
		case Platform::OS
		when :win32
			return(MiqLargeFileWin32.new(file_name, flags))
		when :unix
			if Platform::IMPL == :linux
				return(LargeFileLinux.new(file_name, flags)) if MiqSystem.arch == :x86
				return(RawBlockIO.new(file_name, flags)) if MiqLargeFileStat.new(file_name).blockdev?
			end
			return(MiqLargeFileOther.new(file_name, flags))
		else
			return(MiqLargeFileOther.new(file_name, flags))
		end
	end

    def self.size(file_name)
        case Platform::OS
		when :win32
			# The win32/file require is needed to support +2GB file sizes
			require 'win32/file'
			File.size(file_name)
		else
			f = self.open(file_name, "r")
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
        def write (buf, len)
            super(buf)
        end
      
        def size
            return self.stat.size unless self.stat.blockdev?
			return LinuxBlockDevice.size(self.fileno)
        end
    end
end
