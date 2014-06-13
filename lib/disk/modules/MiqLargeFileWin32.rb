$:.push("#{File.dirname(__FILE__)}/../../util")

require 'MiqMemory'
require 'Win32API'

class MiqLargeFileWin32

	# Access specifiers.
  GENERIC_READ  = 0x80000000
	GENERIC_WRITE	= 0x40000000
	
	# Share specifiers.
  FILE_SHARE_READ   = 0x00000001
  FILE_SHARE_WRITE  = 0x00000002

	# Creation disposition specifiers.
  OPEN_EXISTING = 3

  # Seek origin.
	FILE_BEGIN    = 0
  FILE_CURRENT  = 1
  FILE_END      = 2

  # Misc.
	INVALID_HANDLE_VALUE			= -1
  
  # API.
	@@createFile				= Win32API.new('kernel32', 'CreateFileA',				'PLLLLLL',	'L')
  @@setFilePointerEx	= Win32API.new('kernel32', 'SetFilePointerEx',	'LLLPL',			'L')
  @@readFile					= Win32API.new('kernel32', 'ReadFile',					'LPLPL',		'L')
	@@writeFile					= Win32API.new('kernel32', 'WriteFile',					'LPLPL',		'L')
  @@closeHandle				= Win32API.new('kernel32', 'CloseHandle',				'L',				'L')
	@@getFileSize				= Win32API.new('kernel32', 'GetFileSizeEx',			'LP',				'L')
	@@getLastError			= Win32API.new('kernel32', 'GetLastError',			nil,				'L')
    
  # Default constructor.
  def initialize(file, access = "r")
		accessOptions = 0
		accessOptions |= GENERIC_READ if access.include?("r")
		accessOptions |= GENERIC_WRITE if access.include?("+")
    @hFile = @@createFile.call(file, accessOptions, FILE_SHARE_READ | FILE_SHARE_WRITE, 0, OPEN_EXISTING, 0, 0)
		raise "Couldn't open file #{file}" if @hFile == INVALID_HANDLE_VALUE
		$log.debug("MiqLargeFile<#{self.object_id}> Opening #{file}, handle 0x#{'%08x' % @hFile}") if $log
  end
  
  # Alternative initialization.
  def self.open(file, access = "r")
    initialize(file, access)
  end
  
	def size
		siz = MiqMemory.create_quad_buf
		err = @@getFileSize.call(@hFile, siz)
		return siz.unpack('Q')[0]
	end
	
	def seek(offset, whence)
		method = case whence
			when IO::SEEK_SET then FILE_BEGIN
			when IO::SEEK_CUR then FILE_CURRENT
			when IO::SEEK_END then FILE_END
			else raise "Invalid seek method: #{whence}"
		end
		offHi, offLo = offset.divmod(4294967296) # 2 ** 32
		new_pos = MiqMemory.create_quad_buf
		res = @@setFilePointerEx.call(@hFile, offLo, offHi, new_pos, method)
		if res == 0
      last_error = @@getLastError.call
			raise "SetFilePointerEx failed - Offset:[#{offset}] method:[#{whence}] Handle:[0x#{'%08x' % @hFile}] GetLastErrorNum:[#{last_error}]"
		end
		new_pos = new_pos.unpack('Q')[0]
		return new_pos
  end
  
	def read(bytes)
		#puts "#{getFilePos}, #{bytes}" if $track_pos
		buf = MiqMemory.create_zero_buffer(bytes)
		bytesRead = MiqMemory.create_long_buf
		res = @@readFile.call(@hFile, buf, bytes, bytesRead, 0)
		bytesRead = bytesRead.unpack('L')[0]
		if bytesRead == 0 and bytes != 0 or res == 0
  		last_error = @@getLastError.call
			raise "Read from disk file failed - result:[#{res}] bytesRead:[#{bytesRead}] expected:[#{bytes}] file pointer:[#{getFilePos}] file size:[#{self.size}] Handle:[0x#{'%08x' % @hFile}] GetLastErrorNum:[#{last_error}]."
		end
		buf = buf[0...bytesRead] if bytesRead != bytes
		return buf
  end
  
	def write(buf, len)
		# NOTE: len must be a double word.
		bytesWritten = MiqMemory.create_long_buf
		res = @@writeFile.call(@hFile, buf, len, bytesWritten, 0)
		raise "WriteFile failed" if res == 0
		bytesWritten = bytesWritten.unpack('L')[0]
		raise "Not all data written" if bytesWritten != len
		return bytesWritten
	end
	
  def close
		$log.debug("MiqLargeFile<#{self.object_id}> Closing handle 0x#{'%08x' % @hFile}") if $log
    h = @hFile
		res = @@closeHandle.call(@hFile)
    @hFile = INVALID_HANDLE_VALUE if res != 0
    return res, h
  end
	
	def getFilePos
		seek(0, IO::SEEK_CUR)
	end
end
