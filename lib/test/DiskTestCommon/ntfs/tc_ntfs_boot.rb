require 'test/unit'
require 'ostruct'

$:.push("#{File.dirname(__FILE__)}/../..")
require 'VmsFromYaml'

$:.push("#{File.dirname(__FILE__)}/../../../disk")
require 'MiqDisk'

$:.push("#{File.dirname(__FILE__)}/../../../fs/ntfs")
require 'NtfsBootSect'

class NtfsTestDisk < Test::Unit::TestCase
	
	CONDITIONS = ['fs_type', 'ntfs']
	TEST_DB = "#{File.dirname(__FILE__)}/../../vms.yml"
		
	def initialize(obj)
		#puts "NTFS:tc_ntfs_boot"
		@num_tests = 0
		super(obj)
	end
	
	def test_ntfs_boot_sect
		@num_tests += 1
		vms = VmsFromYaml.new(TEST_DB)
		@disk_specs = vms.find_vms_with_criteria(CONDITIONS)
		#puts "NTFS:tc_ntfs_boot:test_ntfs_boot_sect #{@disk_specs.size} VMs"
		@disks = Array.new
		@disk_specs.each do |spec|
			filename = spec['location']
			next unless File.exists?(filename)
			
			di = OpenStruct.new
			di.fileName = filename
			di.rawDisk = di.fileName.include?('-flat') ? true : false
			dk = MiqDisk.getDisk(di)
			if dk
				thisDisk = OpenStruct.new('info' => di, 'dk' => dk)
				thisDisk.pt = dk.getPartitions[spec['vm_system_partition']]
				@disks << thisDisk
			else
				@disks << nil
				puts "\ntc_ntfs_boot: no disk for #{di.fileName}"
				puts "Spec is:\n#{spec.inspect}"
			end
		end
		
		@disks.each do |disk|
			next if disk.nil?
			#puts "\ntc_ntfs_boot: Testing boot sector on #{disk.info.fileName}"
			assert_instance_of(MiqDisk, disk.pt, id(__LINE__, disk))
			
			# Test normal.
			bs = NTFS::BootSect.new(disk.pt)
			assert_instance_of(NTFS::BootSect, bs, id(__LINE__, disk))
			assert_equal(true, bs.isMountable?, id(__LINE__, disk))
			
			# These values will be common to all versions of NTFS (so far - Vista may be different).
			assert_equal('NTFS', bs.to_s.strip, id(__LINE__, disk))
			assert_equal(512, bs.bytesPerSector, id(__LINE__, disk))
			assert_equal(1024, bs.bytesPerFileRec, id(__LINE__, disk))
			assert_equal(4096, bs.bytesPerIndexRec, id(__LINE__, disk))
			res, h = disk.dk.close if disk.dk
			if h
				puts "Got an invalid handle back from close on #{disk.info.fileName} in #{__FILE__}" if h == -1
			end
		end
	end
	
	def test_ntfs_boot_sect_empty
		@num_tests += 1
		assert_raise(RuntimeError) {NTFS::BootSect.new(nil)}
	end
	
	def id(line, disk)
		return "Failure: Line #{line}, File: #{__FILE__}, Disk: #{disk.info.fileName}"
	end
end
