require 'test/unit'
require 'ostruct'

$:.push("#{File.dirname(__FILE__)}/../..")
require 'VmsFromYaml'

$:.push("#{File.dirname(__FILE__)}/../../../disk")
require 'MiqDisk'

$:.push("#{File.dirname(__FILE__)}/../../../fs/fat32")
require 'Fat32BootSect'

class Fat32TestBoot < Test::Unit::TestCase
	
	CONDITIONS = ['fs_type', 'fat32']
	TEST_DB = "#{File.dirname(__FILE__)}/../../vms.yml"
		
	def initialize(obj)
		#puts "Fat32:tc_fat32_boot"
		@num_tests = 0
		super(obj)
	end
	
	def setup
		vms = VmsFromYaml.new(TEST_DB)
		@disk_specs = vms.find_vms_with_criteria(CONDITIONS)
		#puts "Fat32:tc_fat32_boot:setup found #{@disk_specs.size} VMs"
		@disks = Array.new
		@disk_specs.each do |spec|
			di = OpenStruct.new
			di.fileName = spec['location']
			di.rawDisk = di.fileName.include?('-flat') ? true : false
			dk = MiqDisk.getDisk(di)
			if dk
				thisDisk = OpenStruct.new('info' => di, 'dk' => dk)
				thisDisk.pt = dk.getPartitions[spec['vm_system_partition']]
				@disks << thisDisk
			else
				@disks << nil
				puts "\ntc_fat32_rootdir: no disk for #{di.fileName}"
				puts "Spec is:\n#{spec.inspect}"
			end
		end
	end
	
	def teardown
		@disks.each do |disk|
			next if disk.nil?
			res, h = disk.dk.close if disk.dk
			if h
				puts "Got an invalid handle back from close on #{disk.info.fileName} in #{__FILE__}" if h == -1
			end
		end
	end
	
	def test_fat32_boot_sect_empty
		@num_tests += 1
		assert_raise(RuntimeError) {Fat32::BootSect.new(nil)}
	end
	
	def test_fat32_boot_sect
		@num_tests += 1
		@disks.each do |disk|
			next if disk.nil?
			#puts "\nFat32: Testing boot sector on #{disk.info.fileName}"
			assert_instance_of(MiqDisk, disk.pt, id(__LINE__, disk))
			
			# Test normal.
			bs = Fat32::BootSect.new(disk.pt)
			assert_instance_of(Fat32::BootSect, bs, id(__LINE__, disk))
			assert_equal(true, bs.isMountable?, id(__LINE__, disk))
			
			# There is some disagreement as to whether the FS is positively identified.
			# MS tools always set a file system label, others may not in which case
			# to_s won't come back with the required string.
			assert_equal("FAT32   ", bs.to_s, id(__LINE__, disk))
			
			# Check bytes per sector (should normally be 512, but can vary occasionally).
			# Bytes per cluster must be less than or equal to 32K.
			assert_equal(512, bs.bytesPerSector, id(__LINE__, disk))
			assert_equal(true, bs.bytesPerCluster > 0 && bs.bytesPerCluster <= 32768)
			
			# Must have fat location, fat size & root location.
			assert_equal(true, bs.fatBase > 0, id(__LINE__, disk))
			assert_equal(true, bs.fatSize > 0, id(__LINE__, disk))
			assert_equal(true, bs.rootBase > 0, id(__LINE__, disk))
		end
	end
	
	def id(line, disk)
		return "Failure: Line #{line}, File: #{__FILE__}, Disk: #{disk.info.fileName}"
	end
	
end
