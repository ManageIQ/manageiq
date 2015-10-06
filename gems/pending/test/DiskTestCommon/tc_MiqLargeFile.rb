require 'disk/modules/MiqLargeFile'
require 'metadata/util/md5deep'
require 'enumerator'
require 'minitest/unit'
require 'tmpdir'

module DiskTestCommon
  class TestMiqLargeFile < Minitest::Test
    FILE_PATH = (Sys::Platform::IMPL == :macosx ? "/Volumes" : "/mnt") + "/manageiq/fleecing_test/images/"

    FILE_1MB = FILE_PATH + "containers/raw/DiskTestCommon_MiqLargeFile_1MB"
    FILE_1GB = FILE_PATH + "containers/raw/DiskTestCommon_MiqLargeFile_1GB"
    FILE_4GB = FILE_PATH + "containers/raw/DiskTestCommon_MiqLargeFile_4GB"
    FILE_5GB = FILE_PATH + "containers/raw/DiskTestCommon_MiqLargeFile_5GB"

    SIZE_1MB = 0x00100000
    SIZE_1GB = 0x40000000
    SIZE_4GB = 0x0000000100000000
    SIZE_5GB = 0x0000000140000000

    def setup
      #     unless $log
      #       require 'util/miq-logger'
      #
      #       # Setup console logging
      #       $log = MIQLogger.get_log(nil, nil)
      #     end
    end

    def teardown
    end

    def test_open
      params = [FILE_1MB, FILE_1GB, FILE_4GB, FILE_5GB]

      params.each do |filename|
        next unless File.exist?(filename)

        f = MiqLargeFile.open(filename, "r")
        refute_nil(MiqLargeFile, f)
        f.close
      end
    end

    def test_size
      params = [
        FILE_1MB, SIZE_1MB,
        FILE_1GB, SIZE_1GB,
        FILE_4GB, SIZE_4GB,
        FILE_5GB, SIZE_5GB
      ]

      params.each_slice(2) do |filename, filesize|
        next unless File.exist?(filename)

        # Test both class method and instance method
        f = MiqLargeFile.size(filename)
        assert_equal(filesize, f)
        f = MiqLargeFile.open(filename, "r")
        assert_equal(filesize, f.size)
        f.close
      end
    end

    def test_seek_and_read
      # Note that since offsets are 0 based, then the offsets are -1 from the actual location
      params = [
        FILE_1MB, [0, 0x000003FF, 0x000FFFFF], # Test 1 MB file with markers at 0, 1MB, and every 1 KB
        FILE_1GB, [0, 0x1F3FFFFF, 0x3FFFFFFF], # Test 1 GB file with markers at 0, 500 MB, and 1 GB
        FILE_4GB, [0, 0x0FBAFD3D, 0x7FFFFFFF, 0xC0D9779A, 0xFFFFFFFF], # Test 4 GB file with markers at 0, 0x0FBAFD3D, 2 GB, 0xC0D9779A, and 4 GB
        FILE_5GB, [0, 0x0FBAFD3D, 0x7FFFFFFF, 0xC0D9779A, 0x13FFFFFFF] # Test 5 GB file with markers at 0, 0x0FBAFD3D, 2 GB, 0xC0D9779A, and 5 GB
      ]

      params.each_slice(2) do |filename, offsets|
        next unless File.exist?(filename)

        f = MiqLargeFile.open(filename, "r")
        offsets.each do |offset|
          new_offset = f.seek(offset, IO::SEEK_SET)
          assert_equal(offset, new_offset)

          buf = f.read(1)
          assert_equal("0", buf)
        end
        f.close
      end
    end

    def test_write
      # Copy the file to another file, and compare the file size and the file hash
      params = [
        FILE_1MB, SIZE_1MB, 'd43d86094a3671190422ce5e44aec95c',
        # FILE_1GB, SIZE_1GB, '329246b563db06a656c7c88a19e40588',
        # FILE_4GB, SIZE_4GB, 'b7fb96822fef719280ee9625966a10fb',
        # FILE_5GB, SIZE_5GB, '5c5bcb1e258ffdf69faadc5ae4c09ac4',
      ]

      Dir.mktmpdir do |file_write_path|
        params.each_slice(3) do |filename, filesize, md5|
          next unless File.exist?(filename)

          # Temporarily create the file, as MiqLargeFile only opens existing files
          file_write = File.join(file_write_path, "DiskTestCommon_WriteTest")
          File.new(file_write, "w").close

          # Copy the file 100+ MB at a time
          #   (using an "off" amount to validate that partial reads return properly)
          f = MiqLargeFile.open(filename, "r")
          f2 = MiqLargeFile.open(file_write, "+")
          while f.getFilePos < filesize
            buf = f.read(0x06400123)
            f2.write(buf, buf.length)
            buf = nil
          end
          f.close
          f2.close

          # Get the new file's size
          assert_equal(filesize, MiqLargeFile.size(file_write))

          # Get the md5 hash of the new file
          xml = MD5deep.new.scan(file_write_path)
          assert_equal(md5, xml.root.elements[1].children[0].attributes["md5"])

          File.delete(file_write)
        end
      end
    end
  end
end
