require 'rubygems'
#gem 'Platform'
require 'platform'
$:.push("../../util")
require 'miq-system'

if Platform::IMPL == :linux
	if MiqSystem.arch == :x86
		require 'MiqLargeFileLinux'
	elsif MiqSystem.arch == :x86_64
		require 'MiqBlockDevOps'
		require 'RawBlockIO'
	end
elsif Platform::OS == :win32
	require 'MiqLargeFileWin32'
end

module MiqLargeFile
	def self.open(file_name, flags)
		case Platform::OS
		when :win32
			return(MiqLargeFileWin32.new(file_name, flags))
		when :unix
			if Platform::IMPL == :linux
				return(MiqLargeFileLinux.new(file_name, flags)) if MiqSystem.arch == :x86
				return(RawBlockIO.new(file_name, flags)) if File.stat(file_name).blockdev?
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
	
    class MiqLargeFileOther < File
        def write (buf, len)
            super(buf)
        end
      
        def size
            return self.stat.size unless self.stat.blockdev?
			return MiqBlockDevOps.blkgetsize64(self.fileno)
        end
    end
end
