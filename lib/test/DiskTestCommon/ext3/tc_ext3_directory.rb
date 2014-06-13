require 'ostruct'

$:.push("#{File.dirname(__FILE__)}/../..")
require 'VmsFromYaml'

$:.push("#{File.dirname(__FILE__)}/../../../disk")
require 'MiqDisk'

$:.push("#{File.dirname(__FILE__)}//../../../fs/ext3")
require 'Ext3Superblock'
require 'Ext3Directory'

class Ext3TestDirectory < Test::Unit::TestCase
	
	CONDITIONS = ['fs_type', 'ext3']
	TEST_DB = "#{File.dirname(__FILE__)}/../../vms.yml"
		
	def initialize(obj)
		#puts "Ext3:tc_ext3_directory"
		@num_tests = 0
		super(obj)
	end
	
	def setup
		vms = VmsFromYaml.new(TEST_DB)
		@disk_specs = vms.find_vms_with_criteria(CONDITIONS)
		#puts "Ext3:tc_ext3_directory:setup found #{@disk_specs.size} VMs"
		@disks = Array.new
		@disk_specs.each do |spec|
			di = OpenStruct.new
			di.fileName = spec['location']
			di.rawDisk = di.fileName.include?('-flat') ? true : false
			dk = MiqDisk.getDisk(di)
			if dk
				thisDisk = OpenStruct.new('info' => di, 'dk' => dk)
				thisDisk.sb = Ext3::Superblock.new(dk.getPartitions[spec['vm_system_partition']])
				@disks << thisDisk
			else
				@disks << nil
				puts "\ntc_ext3_directory: no disk for #{di.fileName}"
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
	
	def test_ext3_directory_all_dirs
		@num_tests += 1
		@disks.each do |disk|
			next if disk.nil?
			if disk.sb
				#puts "\ntc_ext3_directory: Testing directories on #{disk.info.fileName}"
				disk.sb.numInodes.times {|inode|
					if disk.sb.isValidInode?(inode)
						inodeObj = nil
						assert_nothing_raised(id(__FILE__, disk)) {inodeObj = disk.sb.getInode(inode)}
						if inodeObj.isDir?
							dirObj = nil
							assert_nothing_raised(id(__FILE__, disk)) {dirObj = Ext3::Directory.new(disk.sb, inode)}
							assert_nothing_raised(id(__FILE__, disk)) {dirObj.globNames}
						end
					end
				}
			else
				puts "\ntc_ext3_directory: Superblock is nil at line #{__LINE__} on #{disk.info.fileName}"
			end
		end
	end
	
	def id(line, disk)
		return "Failure: Line #{line}, File: #{__FILE__}, Disk: #{disk.info.fileName}"
	end
end
