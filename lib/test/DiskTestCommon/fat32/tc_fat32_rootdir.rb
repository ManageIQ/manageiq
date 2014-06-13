require 'test/unit'
require 'ostruct'

$:.push("#{File.dirname(__FILE__)}/../..")
require 'VmsFromYaml'

# FAT32 stuff.
$:.push("#{File.dirname(__FILE__)}/../../../fs/fat32")
require 'Fat32BootSect'
require 'Fat32DirectoryEntry'

# MiqDisk
$:.push("#{File.dirname(__FILE__)}/../../../disk")
require 'MiqDisk'

class Fat32TestRoot < Test::Unit::TestCase
	
	CONDITIONS = ['fs_type', 'fat32']
	TEST_DB = "#{File.dirname(__FILE__)}/../../vms.yml"
	
	def initialize(obj)
		#puts "Fat32:tc_fat32_rootdir"
		@num_tests = 0
		super(obj)
	end
	
	def test_fat32_root_normal
		@num_tests += 1
		vms = VmsFromYaml.new(TEST_DB)
		@disk_specs = vms.find_vms_with_criteria(CONDITIONS)
		#puts "Fat32:tc_fat32_rootdir:test_normal found #{@disk_specs.size} VMs"
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
		
		@disks.each do |disk|
			next if disk.nil?
			#puts "\nFat32: Testing root directory on #{disk.info.fileName}"
			assert_instance_of(MiqDisk, disk.pt, id(__LINE__, disk))
			bs = Fat32::BootSect.new(disk.pt)
			assert_instance_of(Fat32::BootSect, bs, id(__LINE__, disk))
			assert_equal(true, bs.isMountable?, id(__LINE__, disk))
			
			# Get 1st cluster of root in a memory file & wing it.
			assert_nothing_raised(id(__LINE__, disk)) {
				mf = StringIO.new(bs.getCluster(bs.rootCluster))
				0.upto(bs.bytesPerCluster / 32 - 1) {|i|
					de = Fat32::DirectoryEntry.new(mf.read(640))
					break if de.unused.size == 0
					mf = StringIO.new(de.unused)
				}
			}
		end
		@disks.each do |disk|
			next if disk.nil?
			res, h = disk.dk.close if disk.dk
			if h
				puts "Got an invalid handle back from close on #{disk.info.fileName} in #{__FILE__}" if h == -1
			end
		end
	end
	
	def id(line, disk)
		return "Failure: Line #{line}, File: #{__FILE__}, Disk: #{disk.info.fileName}"
	end
		
end
