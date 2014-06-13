$:.push("#{File.dirname(__FILE__)}/../../disk/")
require 'MiqDisk'
require 'ostruct'
require 'enumerator'
require 'test/unit'

module DiskTestCommon
	
	class TestMiqDisk < Test::Unit::TestCase
    FILE_PATH = case Platform::OS
    when :win32 then '//miq-websvr1'
    when :unix  then (Platform::IMPL == :macosx) ? '/Volumes' : '/mnt'
    end + "/Scratch/TestData/miq/lib/test/DiskTestCommon/"

		FILE_SPARSE_8GB = FILE_PATH + "DiskTestCommon_MiqDisk_Sparse8GB.vmdk"
		FILE_SPARSE_5GB = FILE_PATH + "DiskTestCommon_MiqDisk_Sparse5GBFull.vmdk"
		FILE_DESCR_4GB = FILE_PATH + "DiskTestCommon_MiqDisk_Flat4GB.vmdk"
		FILE_FLAT_4GB = FILE_PATH + "DiskTestCommon_MiqDisk_Flat4GB-flat.vmdk"

		SIZE_4GB = 0x0000000100000000
		SIZE_5GB = 0x0000000140000000
		SIZE_8GB = 0x0000000200000000
		SIZE_BLOCK = 0x00010000
		RANDOM_OFFSET = 0xABCC

		def setup
#			unless $log
#				$:.push("#{File.dirname(__FILE__)}/../../util")
#				require 'miq-logger'
#				
#				# Setup console logging
#				$log = MIQLogger.get_log(nil, nil)
#			end
		end
		
		def teardown
		end

		def test_new
			params = [FILE_SPARSE_8GB, false,
							  FILE_SPARSE_5GB, false,
								FILE_DESCR_4GB, false,
								FILE_FLAT_4GB, true]
			
			params.each_slice(2) do |filename, rawDisk|
        diskInfo = OpenStruct.new
				diskInfo.rawDisk = true if rawDisk
        diskInfo.fileName = filename

				d = MiqDisk.getDisk(diskInfo)
				assert_not_nil(MiqDisk, d)
				d.close
			end
		end

		def test_size
			params = [FILE_SPARSE_8GB, SIZE_8GB, false,
							  FILE_SPARSE_5GB, SIZE_5GB, false,
								FILE_DESCR_4GB, SIZE_4GB, false,
								FILE_FLAT_4GB, SIZE_4GB, true]

			params.each_slice(3) do |filename, filesize, rawDisk|
        diskInfo = OpenStruct.new
				diskInfo.rawDisk = true if rawDisk
        diskInfo.fileName = filename

				d = MiqDisk.getDisk(diskInfo)
				d.seek(0, IO::SEEK_END)
				assert_equal(filesize, d.seekPos)
				d.close
			end
		end
		
		def test_Sparse8GB_seek_and_read
			# Test 8GB max sparse disk with only the first 255 blocks filled.  Each block value is a single byte integer.
      diskInfo = OpenStruct.new
      diskInfo.fileName = FILE_SPARSE_8GB
			
			d = MiqDisk.getDisk(diskInfo)
			
			# Read value at 0 position
			d.seek(0, IO::SEEK_SET)
			buf = d.read(1)
			assert_equal(0, buf.unpack('C')[0])
			
			# Read value at last block
			d.seek(SIZE_BLOCK * 255, IO::SEEK_SET)
			buf = d.read(1)
			assert_equal(255, buf.unpack('C')[0])

			# Read random value in block 128
			d.seek(SIZE_BLOCK * 128 + RANDOM_OFFSET, IO::SEEK_SET)
			buf = d.read(1)
			assert_equal(128, buf.unpack('C')[0])
			
			# Read last value
			d.seek(-1, IO::SEEK_END)
			buf = d.read(1)
			assert_equal(0, buf.unpack('C')[0])
			
			d.close
		end

		def test_Sparse5GB_seek_and_read
			# Test 5GB max sparse disk completely filled.  Each block value is a 4-byte integer.
      diskInfo = OpenStruct.new
      diskInfo.fileName = FILE_SPARSE_5GB
			
			d = MiqDisk.getDisk(diskInfo)
			
			# Read value at 0 position
			d.seek(0, IO::SEEK_SET)
			buf = d.read(4)
			assert_equal(0, buf.unpack('L')[0])
			
			# Read value block 0xFF
			d.seek(SIZE_BLOCK * 0xFF, IO::SEEK_SET)
			buf = d.read(4)
			assert_equal(0xFF, buf.unpack('L')[0])
			
			# Read random value in block 0xFFFF
			d.seek(SIZE_BLOCK * 0x0000FFFF + RANDOM_OFFSET, IO::SEEK_SET)
			buf = d.read(4)
			assert_equal(0x0000FFFF, buf.unpack('L')[0])
			
			# Read value at last block
			d.seek(SIZE_BLOCK * 0x00013FFF, IO::SEEK_SET)
			buf = d.read(4)
			assert_equal(0x00013FFF, buf.unpack('L')[0])
			
			# Read last value
			d.seek(-4, IO::SEEK_END)
			buf = d.read(4)
			assert_equal(0x00013FFF, buf.unpack('L')[0])
			
			d.close
		end

		def test_Flat4GB_seek_and_read
			# Test 4GB max flat disk completely filled.  Each block value is a 2-byte integer.
      diskInfo = OpenStruct.new
      diskInfo.fileName = FILE_DESCR_4GB
			
			d = MiqDisk.getDisk(diskInfo)
			
			# Read value at 0 position
			d.seek(0, IO::SEEK_SET)
			buf = d.read(2)
			assert_equal(0, buf.unpack('S')[0])
			
			# Read value block 0xFF
			d.seek(SIZE_BLOCK * 0xFF, IO::SEEK_SET)
			buf = d.read(2)
			assert_equal(0xFF, buf.unpack('S')[0])
			
			# Read random value in block 0xAAFF
			d.seek(SIZE_BLOCK * 0xAAFF + RANDOM_OFFSET, IO::SEEK_SET)
			buf = d.read(2)
			assert_equal(0xAAFF, buf.unpack('S')[0])
			
			# Read value at last block
			d.seek(SIZE_BLOCK * 0x0000FFFF, IO::SEEK_SET)
			buf = d.read(2)
			assert_equal(0x0000FFFF, buf.unpack('S')[0])
			
			# Read last value
			d.seek(-2, IO::SEEK_END)
			buf = d.read(2)
			assert_equal(0x0000FFFF, buf.unpack('S')[0])
			
			d.close
		end

		def test_Flat4GBRaw_seek_and_read
			# Test 4GB max flat disk completely filled.  Each block value is a 2-byte integer.
      diskInfo = OpenStruct.new
			diskInfo.rawDisk = true
      diskInfo.fileName = FILE_FLAT_4GB
			
			d = MiqDisk.getDisk(diskInfo)
			
			# Read value at 0 position
			d.seek(0, IO::SEEK_SET)
			buf = d.read(2)
			assert_equal(0, buf.unpack('S')[0])
			
			# Read value block 0xFF
			d.seek(SIZE_BLOCK * 0xFF, IO::SEEK_SET)
			buf = d.read(2)
			assert_equal(0xFF, buf.unpack('S')[0])
			
			# Read random value in block 0xAAFF
			d.seek(SIZE_BLOCK * 0xAAFF + RANDOM_OFFSET, IO::SEEK_SET)
			buf = d.read(2)
			assert_equal(0xAAFF, buf.unpack('S')[0])
			
			# Read value at last block
			d.seek(SIZE_BLOCK * 0x0000FFFF, IO::SEEK_SET)
			buf = d.read(2)
			assert_equal(0x0000FFFF, buf.unpack('S')[0])
			
			# Read last value
			d.seek(-2, IO::SEEK_END)
			buf = d.read(2)
			assert_equal(0x0000FFFF, buf.unpack('S')[0])
			
			d.close
		end
	end
end
