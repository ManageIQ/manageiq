require 'test/unit'
require 'ostruct'

$:.push("#{File.dirname(__FILE__)}/../..")
require 'VmsFromYaml'

$:.push("#{File.dirname(__FILE__)}/../../../disk")
require 'MiqDisk'

$:.push("#{File.dirname(__FILE__)}/../../../fs/ntfs")
require 'NtfsBootSect'
require 'NtfsMftEntry'

class NtfsTestIndex < Test::Unit::TestCase
	
	CONDITIONS = ['fs_type', 'ntfs']
	TEST_DB = "#{File.dirname(__FILE__)}/../../vms.yml"
		
	def initialize(obj)
		#puts "NTFS:tc_ntfs_index"
		@num_tests = 0
		super(obj)
	end
	
	def test_ntfs_index
		@num_tests += 1
		vms = VmsFromYaml.new(TEST_DB)
		@disk_specs = vms.find_vms_with_criteria(CONDITIONS)
		#puts "NTFS:tc_ntfs_index:test_ntfs_index found #{@disk_specs.size} VMs"
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
				puts "\ntc_ntfs_index: no disk for #{di.fileName}"
				puts "Spec is:\n#{spec.inspect}"
			end
		end
		
		@disks.each do |disk|
			next if disk.nil?
			#puts "\ntc_ntfs_index: Testing root index on #{disk.info.fileName}"
			assert_instance_of(MiqDisk, disk.pt, id(__LINE__, disk))
			
			# Get drive root index.
			bs = NTFS::BootSect.new(disk.pt)
			assert_instance_of(NTFS::BootSect, bs, id(__LINE__, disk))
			#puts "tc_ntfs_index: Boot sector confirmed\n\n"
			root = nil
			assert_nothing_raised(id(__LINE__, disk)) {root = NTFS::MftEntry.new(bs, 5)}
			assert_instance_of(NTFS::MftEntry, root, id(__LINE__, disk))
			assert_nothing_raised(id(__LINE__, disk)) {root = root.getAttrib(NTFS::AT_INDEX_ROOT)}
			assert_equal(true, root.class == Array)
			assert_equal(true, root[0].class == NTFS::AttribHeader)
			assert_equal("$I30", root[0].name)
			assert_equal(true, root[1].class == NTFS::IndexRoot)
			assert_equal(4096, root[1].byteSize)
			
			res, h = disk.dk.close if disk.dk
			if h
				puts "Got an invalid handle back from close on #{disk.info.fileName} in #{__FILE__}" if h == -1
			end
		end
	end
	
	def test_ntfs_index_empty_index
		@num_tests += 1
		assert_raise(RuntimeError) {NTFS::IndexRoot.new(nil, nil)}
		assert_raise(RuntimeError) {NTFS::IndexRoot.new(1, nil)}
		assert_raise(RuntimeError) {NTFS::IndexRoot.new(nil, 1)}
	end
	
	def id(line, disk)
		return "Failure: Line #{line}, File: #{__FILE__}, Disk: #{disk.info.fileName}"
	end
end
