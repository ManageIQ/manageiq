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

    FILE_DESC_4GB   = FILE_PATH + "DiskTestCommon_MiqDisk_Flat4GB.vmdk"
    FILE_FLAT_4GB   = FILE_PATH + "DiskTestCommon_MiqDisk_Flat4GB-flat.vmdk"    
    FILE_SPRS_5GB   = FILE_PATH + "DiskTestCommon_MiqDisk_Sparse5GBFull.vmdk" 
    FILE_SPRS_8GB   = FILE_PATH + "DiskTestCommon_MiqDisk_Sparse8GB.vmdk"
    FILE_COWD_256MB = FILE_PATH + "COWD/debian40server_4-000001-delta.vmdk"
    FILE_MLTD_8GB   = FILE_PATH + "MULTIDISK/8GB/debian40server-3.vmdk"
    FILE_PCHL_256MB = FILE_PATH + "PARENTCHILD/debian40server-9-000001.vmdk"
    FILE_OFST_1GB   = FILE_PATH + "OFFSETINBLOCK/debian40server-12.vmdk"
    FILE_PRTN_256MB = FILE_PATH + "PARTITION/debian40server-18.vmdk"
    FILE_PRTN1_256MB = FILE_PATH + "PARTITION/debian40server-21.vmdk" 
    
    SIZE_32MB  = 0x0000000002000000
    SIZE_64MB  = 0x0000000004000000
    SIZE_128MB = 0x0000000008000000
    SIZE_256MB = 0x0000000010000000
    SIZE_1GB   = 0x0000000040000000
    SIZE_4GB   = 0x0000000100000000
    SIZE_5GB   = 0x0000000140000000
    SIZE_8GB   = 0x0000000200000000
    SIZE_BLOCK = 0x00010000
    RANDOM_OFFSET = 0xABCC

    def setup
#      unless $log
#      $:.push("#{File.dirname(__FILE__)}/../../util")
#      require 'miq-logger'
#				
#      # Setup console logging
#      $log = MIQLogger.get_log(nil, nil)
#      end
    end
		
    def teardown
    end

    def test_new
      params = [FILE_DESC_4GB,   false,
		FILE_FLAT_4GB,   true,
                FILE_SPRS_5GB,   false,
                FILE_SPRS_8GB,   false,
                FILE_COWD_256MB, false,
                FILE_MLTD_8GB,   false,
                FILE_PCHL_256MB, false,
                FILE_OFST_1GB,   false,
                FILE_PRTN_256MB, false
		]
			
      params.each_slice(2) do |filename, rawDisk|
        next unless File.exists?(filename)

        diskInfo = OpenStruct.new
				diskInfo.rawDisk = true if rawDisk
        diskInfo.fileName = filename

				d = MiqDisk.getDisk(diskInfo)
				assert_not_nil(MiqDisk, d)
				d.close
      end
    end

    def test_size
      params = [FILE_DESC_4GB,   SIZE_4GB,   false,
                FILE_FLAT_4GB,   SIZE_4GB,   true,
                FILE_SPRS_5GB,   SIZE_5GB,   false,
                FILE_SPRS_8GB,   SIZE_8GB,   false,
                FILE_COWD_256MB, SIZE_256MB, false,
                FILE_MLTD_8GB,   SIZE_8GB,   false,
                FILE_PCHL_256MB, SIZE_256MB, false,
                FILE_OFST_1GB,   SIZE_1GB,   false,
                FILE_PRTN_256MB, SIZE_256MB, false
      ]

      params.each_slice(3) do |filename, filesize, rawDisk|
        next unless File.exists?(filename)

        diskInfo = OpenStruct.new
        diskInfo.rawDisk = true if rawDisk
        diskInfo.fileName = filename

        d = MiqDisk.getDisk(diskInfo)
        d.seek(0, IO::SEEK_END)
        assert_equal(filesize, d.seekPos)
        d.close
      end
    end
	
    #
    # Test 8GB disk with only the first 255 blocks filled. 
    #
    def test_8gb_seek_and_read          
      params = [FILE_SPRS_8GB]
      params.each do |filename|
        next unless File.exists?(filename)

        diskInfo = OpenStruct.new
        diskInfo.fileName = filename
        d = MiqDisk.getDisk(diskInfo)
			
        # Read value at 0 position
        d.seek(0)
        buf = d.read(1)
        assert_equal(0, buf.unpack('C')[0])
			
        # Read value at last block
        d.seek(SIZE_BLOCK * 255)
        buf = d.read(1)
        assert_equal(255, buf.unpack('C')[0])

        # Read random value in block 128
        d.seek(SIZE_BLOCK * 128 + RANDOM_OFFSET)
        buf = d.read(1)
        assert_equal(128, buf.unpack('C')[0])
			
        # Read last value
        d.seek(-1, IO::SEEK_END)
        buf = d.read(1)
        assert_equal(0, buf.unpack('C')[0])
        
        for ofst in [1, 4, 11]
          i = 250
          while i < 254
           d.seek(i*SIZE_BLOCK + 4*ofst)
           buf = d.read(SIZE_BLOCK)
           16384.times { |x|
             tmp = buf[4*x, 1].unpack('C')[0]
             if x < (16384 - ofst)
               assert_equal(i, tmp)
             else
               assert_equal(i+1, tmp)
             end 
           }
          i += 1
         end
        end
			
        d.close
      end
    end
    
    #
    # Test 8GB sparse multi-disk split into four 2GB disks. 
    # 
    def test_multi_8gb_seek_and_read
			filename = FILE_MLTD_8GB
	    return unless File.exists?(filename)
  
      # Disk format: 1st and 3rd disks have only the first and last blocks 
      # filled with 1 and 3, respectively; 2nd and 4th disks are completely 
      # filled with 2 and 4, respectively.
      dsize = 2*1024*1024*1024     
      diskInfo = OpenStruct.new
      diskInfo.fileName = filename		
      d = MiqDisk.getDisk(diskInfo)
      
      # Test the first four and the last four bytes in each disk
      for i in [1, 2, 3, 4]
        # Read first four bytes from a disk
        d.seek((i-1)*dsize)
        buf = d.read(4)
        assert_equal(i, buf.unpack('L')[0])
        # Read last four bytes from a disk
        d.seek(i*dsize - 4)
        buf = d.read(4) 
        assert_equal(i, buf.unpack('L')[0])
      end			
      
      # Test offset reading of one block at the border between adjacent disks.
      for ofst in [1, 2, 3, 4]
        for i in [1, 2, 3]
          d.seek(i*dsize - SIZE_BLOCK + 4*ofst)
          buf = d.read(SIZE_BLOCK)
          16384.times { |x|
            tmp = buf[4*x, 4].unpack('L')[0]
            if x < (16384 - ofst)
              assert_equal(i, tmp)
            else
              assert_equal(i+1, tmp)
            end 
          }
        end
      end
      d.close
    end
  
    #
    # Test offset reading of the block at the border between adjacent blocks.  
    #
    def test_offset_256mb_cowd_seek_and_read
			filename = FILE_COWD_256MB
	    return unless File.exists?(filename)
  	
      # Disk format: each block has its corresponding number repeated over it
      diskInfo = OpenStruct.new
      diskInfo.fileName = filename	
      d = MiqDisk.getDisk(diskInfo)
      for ofst in [1, 2, 7]
        i = 250
        while i < 255
          d.seek(i*512 + 4*ofst)
          buf = d.read(512)
          128.times { |x|
            tmp = buf[4*x, 4].unpack('L')[0]
            if x < (128 - ofst)
              assert_equal(2*i, tmp)
            else
              #puts "#{tmp}"
              assert_equal(2*(i+1), tmp)
            end 
          }
          i += 1
        end
      end
      d.close
    end
    
    #
    # Test offset reading of the block at the border between adjacent blocks.  
    #
    def test_offset_1gb_seek_and_read
			filename = FILE_OFST_1GB
	    return unless File.exists?(filename)
  	
      # Disk format: each block has its corresponding number repeated over it
      diskInfo = OpenStruct.new
      diskInfo.fileName = filename		
      d = MiqDisk.getDisk(diskInfo)
      for ofst in [1, 4, 5, 7]
        i = 250
        while i < 255
          d.seek(i*SIZE_BLOCK + 4*ofst)
          buf = d.read(SIZE_BLOCK)
          16384.times { |x|
            tmp = buf[4*x, 4].unpack('L')[0]
            if x < (16384 - ofst)
              assert_equal(i, tmp)
            else
              assert_equal(i+1, tmp)
            end 
          }
          i += 1
        end
      end
      d.close
    end
    
     #
    # Test offset reading of the block at the border between adjacent blocks.  
    #
    def test_partition_256mb_seek_and_read
      # Disk format: each block has its corresponding number repeated over it
 #     diskInfo = OpenStruct.new
 #     diskInfo.fileName = FILE_PRTN_256MB	
 #     d = MiqDisk.getDisk(diskInfo)
 #     partitions = d.getPartitions
 #     d1 = partitions[0]
 #     d2 = partitions[1]
 #     d3 = partitions[2]
 #     d4 = partitions[3] 
      
      
 #     params = [d1,   63472*1024,   
#		d2,   32768*1024,    
#                d3,   32768*1024,
#                d4,   125936*1024
#		]

#      params.each_slice(2) do |disk, filesize|
#	disk.seek(0, IO::SEEK_END)
#	assert_equal(filesize, disk.seekPos)
#      end
      
#      d1.seek(0) 
#      buf = d1.read(63472*1024)
#      16248832.times { |x|
#        tmp = buf[4*x, 4].unpack('L')[0]
#        assert_equal(1, tmp) 
#      }
      
#      d2.seek(0)      
#      buf = d2.read(8388608*4)
#      8388608.times { |x|
#        tmp = buf[4*x, 4].unpack('L')[0]
#        assert_equal(2, tmp) 
#      }      
    
#      d3.seek(0) 
#      buf = d3.read(8388608*4)
#      8388608.times { |x|
#        tmp = buf[4*x, 4].unpack('L')[0]
#        assert_equal(3, tmp) 
#      } 
    
#     d4.seek(0) 
#     buf = d4.read(125936*1024)
#     32239616.times { |x|
#       tmp = buf[4*x, 4].unpack('L')[0]
#       assert_equal(4, tmp) 
#     }  
      
#     d.close
     
			filename = FILE_PRTN1_256MB
			return unless File.exists?(filename)

 			diskInfo = OpenStruct.new
      diskInfo.fileName = filename	
      d = MiqDisk.getDisk(diskInfo)
      partitions = d.getPartitions
      d1 = partitions[0]
      d2 = partitions[1]
      d3 = partitions[2]
      d5 = partitions[3] 
      d6 = partitions[4] 
      d7 = partitions[5]  
      
      params = [d1,   63472*1024,   
		d2,   32768*1024,    
                d3,   32768*1024,
                d5,   32752*1024,
                d6,   63472*1024,
                d7,   29680*1024
		]

      params.each_slice(2) do |disk, filesize|
	disk.seek(0, IO::SEEK_END)
	assert_equal(filesize, disk.seekPos)
      end
      
      d1.seek(0) 
      buf = d1.read(63472*1024)
      16248832.times { |x|
        tmp = buf[4*x, 4].unpack('L')[0]
        assert_equal(1, tmp) 
      }
    
      d2.seek(0) 
      buf = d1.read(32768*1024)
      8388608.times { |x|
        tmp = buf[4*x, 4].unpack('L')[0]
        assert_equal(2, tmp) 
      }
      
      d3.seek(0) 
      buf = d1.read(32768*1024)
      8388608.times { |x|
        tmp = buf[4*x, 4].unpack('L')[0]
        assert_equal(3, tmp) 
      }
      
      d5.seek(0) 
      buf = d5.read(32752*1024)
      8384512.times { |x|
        tmp = buf[4*x, 4].unpack('L')[0]
        assert_equal(10, tmp) 
      }
      
      d6.seek(0) 
      buf = d6.read(63472*1024)
      16248832.times { |x|
        tmp = buf[4*x, 4].unpack('L')[0]
        assert_equal(6, tmp) 
      }
      
      d7.seek(0) 
      buf = d7.read(29680*1024)
      7598080.times { |x|
        tmp = buf[4*x, 4].unpack('L')[0]
        assert_equal(7, tmp) 
      }

     d.close            
    end
    
    #
    # Test 1GB multi disk.  
    #
    def test_parent_child_256mb_seek_and_read
			filename = FILE_PCHL_256MB
			return unless File.exists?(filename)

      diskInfo = OpenStruct.new
      diskInfo.fileName = filename		
      d = MiqDisk.getDisk(diskInfo)
      i = 0
      @tmp1 = 0
      @tmp2 = 0
      while i < 4096
        # Read first four bytes in a block
        d.seek(i*SIZE_BLOCK)
        buf = d.read(4)
        tmp = buf.unpack('L')[0]
        if (i % 2 == 1)
          @tmp1 += 1 
          assert_equal(i, buf.unpack('L')[0])  
        else
          @tmp2 += 1
          tmp /= 2
          
          assert_equal(2*i, buf.unpack('L')[0])  
        end    
        i += 1
      end
      d.close
    end
    
    
    
    #
    # Test 5GB max sparse disk completely filled. 
    #
    def test_5gb_seek_and_read
      params = [FILE_SPRS_5GB]
      params.each do |filename|
        next unless File.exists?(filename)
        
        diskInfo = OpenStruct.new
        diskInfo.fileName = filename			
        d = MiqDisk.getDisk(diskInfo)
			
        # Read value at 0 position
        d.seek(0)
        buf = d.read(4)
        assert_equal(0, buf.unpack('L')[0])
			
        # Read value block 0xFF
        d.seek(SIZE_BLOCK * 0xFF)
        buf = d.read(4)
        assert_equal(0xFF, buf.unpack('L')[0])
			
        # Read random value in block 0xFFFF
        d.seek(SIZE_BLOCK * 0x0000FFFF + RANDOM_OFFSET)
        buf = d.read(4)
        assert_equal(0x0000FFFF, buf.unpack('L')[0])
			
        # Read value at last block
        d.seek(SIZE_BLOCK * 0x00013FFF)
        buf = d.read(4)
        assert_equal(0x00013FFF, buf.unpack('L')[0])
			
        # Read last value
        d.seek(-4, IO::SEEK_END)
        buf = d.read(4)
        assert_equal(0x00013FFF, buf.unpack('L')[0])
			
        d.close
      end
    end

    #
    # Test 4GB max flat disk completely filled. 
    #
    def test_flat4gb_seek_and_read
      params = [FILE_DESC_4GB]
      params.each do |filename|
	      next unless File.exists?(filename)
  
        diskInfo = OpenStruct.new
        diskInfo.fileName = filename
        d = MiqDisk.getDisk(diskInfo)
			
        # Read value at 0 position
        d.seek(0)
        buf = d.read(2)
        assert_equal(0, buf.unpack('S')[0])
			
        # Read value block 0xFF
        d.seek(SIZE_BLOCK * 0xFF)
        buf = d.read(2)
        assert_equal(0xFF, buf.unpack('S')[0])
			
        # Read random value in block 0xAAFF
        d.seek(SIZE_BLOCK * 0xAAFF + RANDOM_OFFSET)
        buf = d.read(2)
        assert_equal(0xAAFF, buf.unpack('S')[0])
			
        # Read value at last block
        d.seek(SIZE_BLOCK * 0x0000FFFF)
        buf = d.read(2)
        assert_equal(0x0000FFFF, buf.unpack('S')[0])
			
        # Read last value
        d.seek(-2, IO::SEEK_END)
        buf = d.read(2)
        assert_equal(0x0000FFFF, buf.unpack('S')[0])
			
        d.close
      end
    end
    
    def test_Flat4GBRaw_seek_and_read
			filename = FILE_FLAT_4GB
			return unless File.exists?(filename)

      diskInfo = OpenStruct.new
      diskInfo.rawDisk = true
      diskInfo.fileName = filename
			
      d = MiqDisk.getDisk(diskInfo)
			
      # Read value at 0 position
      d.seek(0)
      buf = d.read(2)
      assert_equal(0, buf.unpack('S')[0])
			
      # Read value block 0xFF
      d.seek(SIZE_BLOCK * 0xFF)
      buf = d.read(2)
      assert_equal(0xFF, buf.unpack('S')[0])
			
      # Read random value in block 0xAAFF
      d.seek(SIZE_BLOCK * 0xAAFF + RANDOM_OFFSET)
      buf = d.read(2)
      assert_equal(0xAAFF, buf.unpack('S')[0])
			
      # Read value at last block
      d.seek(SIZE_BLOCK * 0x0000FFFF)
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
