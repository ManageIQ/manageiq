require 'ostruct'

$:.push("#{File.dirname(__FILE__)}/../..")
require 'VmsFromYaml'

$:.push("#{File.dirname(__FILE__)}/../../../disk")
require 'MiqDisk'

$:.push("#{File.dirname(__FILE__)}//../../../fs/ext3")
require 'Ext3Superblock'

class Ext3TestSuperblock < Test::Unit::TestCase
	
	CONDITIONS = ['fs_type', 'ext3']
	TEST_DB = "#{File.dirname(__FILE__)}/../../vms.yml"
		
	def initialize(obj)
		#puts "Ext3:tc_ext3_superblock"
		@num_tests = 0
		super(obj)
	end
	
	def setup
		vms = VmsFromYaml.new(TEST_DB)
		@disk_specs = vms.find_vms_with_criteria(CONDITIONS)
		#puts "Ext3:tc_ext3_superblock:setup found #{@disk_specs.size} VMs"
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
				puts "\ntc_ext3_superblock: no disk for #{di.fileName}"
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
	
	def test_ext3_superblock
		@num_tests += 1
		@disks.each do |disk|
			next if disk.nil?
			if disk.sb
				#puts "\ntc_ext3_superblock: Testing Superblock on #{disk.info.fileName}"
				assert_equal(disk.sb.blockSize >= 1024, true, id(__LINE__, disk))
				assert_equal(disk.sb.blockSize <= 4096, true, id(__LINE__, disk))
				assert_equal(disk.sb.blockSize, disk.sb.fragmentSize, id(__LINE__, disk))
				assert_equal(disk.sb.blocksPerGroup, disk.sb.fragmentsPerGroup, id(__LINE__, disk))
			else
				puts "\ntc_ext3_superblock: Superblock is nil at line #{__LINE__} on #{disk.info.fileName}"
			end
		end
	end
	
	def test_ext3_superblock_inodes
		@num_tests += 1
		@disks.each do |disk|
			next if disk.nil?
			if disk.sb
				#puts "\ntc_ext3_superblock: Testing inodes on #{disk.info.fileName}"
				disk.sb.numInodes.times {|inode|
					assert_nothing_raised(id(__LINE__, disk)) {disk.sb.getInode(inode) if disk.sb.isValidInode?(inode)}
				}
			else
				puts "\ntc_ext3_superblock: Superblock is nil at line #{__LINE__} on #{disk.info.fileName}"
			end
		end
	end
	
	def test_ext3_superblock_blocks
		if $miq_test_deep
			@num_tests += 1
			@disks.each do |disk|
				next if disk.nil?
				if disk.sb
					#puts "\ntc_ext3_superblock: Testing blocks on #{disk.info.fileName}"
					disk.sb.numBlocks.times {|block|
						assert_nothing_raised(id(__LINE__, disk)) {disk.sb.getBlock(block) if disk.sb.isValidBlock?(block)}
					}
				else
					puts "/ntc_ext3_superblock: Superblock is nil at line #{__LINE__} on #{disk.info.fileName}"
				end
			end
		end
	end
	
	def enum_ext3_superblock_all_blocks
		if $miq_test_deep
			@num_tests += 1
			@disks.each do |disk|
				next if disk.nil?
				if disk.sb
					disk.sb.numBlocks.times {|block|
						assert_nothing_raised(id(__LINE__, disk)) {disk.sb.getBlock(block, true)}
					}
				end
			end
		end
	end
	
	def id(line, disk)
		return "Failure: Line #{line}, File: #{__FILE__}, Disk: #{disk.info.fileName}"
	end
end
