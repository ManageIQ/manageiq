require 'test/unit'
require 'ostruct'

$:.push("#{File.dirname(__FILE__)}/../..")
require 'VmsFromYaml'

$:.push("#{File.dirname(__FILE__)}/../../../disk")
require 'MiqDisk'

$:.push("#{File.dirname(__FILE__)}/../../../fs/MiqFS")
require 'MiqFS'

$:.push("#{File.dirname(__FILE__)}/../../../fs/fat32")
require 'Fat32BootSect'

$:.push("#{File.dirname(__FILE__)}/..")
require 'FSTestUtil'

class Fat32TestWrite < Test::Unit::TestCase
	
	TEST_SHORT_DIR = "/test"
	TEST_LONG_DIR  = "/Test Directory"
	TEST_SHORT_FILE = "test.txt"
	TEST_LONG_FILE  = "TestFileName.txt"
	TEST_FIRST = "This is first."
	TEST_SECOND = "This is second."
	TEST_GRAY_DIR = "/123456789"
	TEST_GRAY_FILE = "123456789"
	
	CONDITIONS = ['fs_type', 'fat32']
	TEST_DB = "#{File.dirname(__FILE__)}/../../vms.yml"
	
	def initialize(obj)
		#puts "Fat32:tc_fat32_write"
		@num_tests = 0
		super(obj)
	end
	
	def setup
		vms = VmsFromYaml.new(TEST_DB)
		@disk_specs = vms.find_vms_with_criteria(CONDITIONS)
		#puts "Fat32:tc_fat32_write:setup found #{@disk_specs.size} VMs"
		@disks = Array.new
		@disk_specs.each do |spec|
			di = OpenStruct.new
			di.fileName = spec['location']
			di.rawDisk = di.fileName.include?('-flat') ? true : false
			dk = MiqDisk.getDisk(di)
			if dk
				thisDisk = OpenStruct.new('info' => di, 'dk' => dk)
				thisDisk.fs = MiqFS.getFS(dk.getPartitions[spec['vm_system_partition']])
				thisDisk.bs = Fat32::BootSect.new(dk.getPartitions[spec['vm_system_partition']])
				@disks << thisDisk
			else
				@disks << nil
				puts "\ntc_fat32_write: no disk for #{di.fileName}"
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
	
	def test_fat32_write_dir
		if $miq_test_write
			@num_tests += 1
			@disks.each do |disk|
				next if disk.nil?
				if disk.fs
					#puts "\nFat32: Testing write directory on #{disk.info.fileName}"
					# Test short name.
					assert_raise(RuntimeError) {disk.fs.dirRmdir(TEST_SHORT_DIR)}
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.dirMkdir(TEST_SHORT_DIR)}
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileCtime(TEST_SHORT_DIR)}
					disk.fs.chdir(TEST_SHORT_DIR)
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.dirRmdir(TEST_SHORT_DIR)}
					assert_raise(RuntimeError) {disk.fs.dirEntries("*.*")}
					disk.fs.chdir("/")
					
					# Test long name.
					assert_raise(RuntimeError) {disk.fs.dirRmdir(TEST_LONG_DIR)}
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.dirMkdir(TEST_LONG_DIR)}
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileCtime(TEST_LONG_DIR)}
					disk.fs.chdir(TEST_LONG_DIR)
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.dirRmdir(TEST_LONG_DIR)}
					assert_raise(RuntimeError) {disk.fs.dirEntries("*.*")}
					disk.fs.chdir("/")
					
					# Test gray name.
					assert_raise(RuntimeError) {disk.fs.dirRmdir(TEST_GRAY_DIR)}
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.dirMkdir(TEST_GRAY_DIR)}
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileCtime(TEST_GRAY_DIR)}
					disk.fs.chdir(TEST_GRAY_DIR)
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.dirRmdir(TEST_GRAY_DIR)}
					assert_raise(RuntimeError) {disk.fs.dirEntries("*.*")}
					disk.fs.chdir("/")
				else
					puts "\ntc_fat32_write: FS is nil at line #{__LINE__} on #{disk.info.fileName}"
				end
		end
		end
	end
	
	def test_fat32_write_create_delete
		@num_tests += 1
		@disks.each do |disk|
			next if disk.nil?
			if disk.fs
				#puts "\nFat32: Testing dir create/delete on #{disk.info.fileName}"
				# Test short name.
				disk.fs.chdir("/")
				f = nil
				assert_nothing_raised(id(__LINE__, disk)) {f = disk.fs.fileOpen(TEST_SHORT_FILE)}
				assert_nothing_raised(id(__LINE__, disk)) {f.close}
				assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileCtime(TEST_SHORT_FILE)}
				assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileDelete(TEST_SHORT_FILE)}
				assert_raise(RuntimeError) {f = disk.fs.fileOpen(TEST_SHORT_FILE, "r")}
				
				# Test long name.
				f = nil
				assert_nothing_raised(id(__LINE__, disk)) {f = disk.fs.fileOpen(TEST_LONG_FILE, "w")}
				assert_nothing_raised(id(__LINE__, disk)) {f.close}
				assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileCtime(TEST_LONG_FILE)}
				assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileDelete(TEST_LONG_FILE)}
				assert_raise(RuntimeError) {f = disk.fs.fileOpen(TEST_LONG_FILE, "r")}
				
				# Test gray name.
				f = nil
				assert_nothing_raised(id(__LINE__, disk)) {f = disk.fs.fileOpen(TEST_GRAY_FILE, "w")}
				assert_nothing_raised(id(__LINE__, disk)) {f.close}
				assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileCtime(TEST_GRAY_FILE)}
				assert_nothing_raised {disk.fs.fileDelete(TEST_GRAY_FILE)}
				assert_raise(RuntimeError) {f = disk.fs.fileOpen(TEST_GRAY_FILE, "r")}
			else
				puts "\ntc_fat32_write: FS is nil at line #{__LINE__} on #{disk.info.fileName}"
			end
		end
	end
	
	def test_fat32_write_modes
		@num_tests += 1
		@disks.each do |disk|
			next if disk.nil?
			if disk.fs
				#puts "\nFat32: Testing write file modes on #{disk.info.fileName}"
				# Open directory should always raise error.
				assert_nothing_raised(id(__LINE__, disk)) {disk.fs.dirMkdir(TEST_SHORT_DIR)}
				assert_raise(RuntimeError) {f = disk.fs.fileOpen(TEST_SHORT_DIR, "r")}
				assert_raise(RuntimeError) {f = disk.fs.fileOpen(TEST_SHORT_DIR, "w")}
				assert_raise(RuntimeError) {f = disk.fs.fileOpen(TEST_SHORT_DIR, "a")}

				disk.fs.chdir(TEST_SHORT_DIR)
				f = nil; buf = nil
				assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileDelete(TEST_SHORT_FILE)}
				assert_raise(RuntimeError) {f = disk.fs.fileOpen(TEST_SHORT_FILE, "r")}
				assert_nothing_raised(id(__LINE__, disk)) {f = disk.fs.fileOpen(TEST_SHORT_FILE, "w")}
				assert_nothing_raised(id(__LINE__, disk)) {f.write(TEST_FIRST)}
				assert_nothing_raised(id(__LINE__, disk)) {f.close}
				assert_nothing_raised(id(__LINE__, disk)) {f = disk.fs.fileOpen(TEST_SHORT_FILE, "r")}
				assert_nothing_raised(id(__LINE__, disk)) {buf = f.read}
				assert_nothing_raised(id(__LINE__, disk)) {f.close}
				assert_equal(TEST_FIRST, buf, id(__LINE__, disk))
				assert_nothing_raised(id(__LINE__, disk)) {f = disk.fs.fileOpen(TEST_SHORT_FILE, "w")}
				assert_nothing_raised(id(__LINE__, disk)) {f.write(TEST_SECOND)}
				assert_nothing_raised(id(__LINE__, disk)) {f.close}
				assert_nothing_raised(id(__LINE__, disk)) {f = disk.fs.fileOpen(TEST_SHORT_FILE, "r")}
				assert_nothing_raised(id(__LINE__, disk)) {buf = f.read}
				assert_nothing_raised(id(__LINE__, disk)) {f.close}
				assert_equal(TEST_SECOND, buf, id(__LINE__, disk))
				assert_nothing_raised(id(__LINE__, disk)) {f = disk.fs.fileOpen(TEST_SHORT_FILE, "w")}
				assert_nothing_raised(id(__LINE__, disk)) {f.write(TEST_FIRST)}
				assert_nothing_raised(id(__LINE__, disk)) {f.close}
				assert_nothing_raised(id(__LINE__, disk)) {f = disk.fs.fileOpen(TEST_SHORT_FILE, "a")}
				assert_nothing_raised(id(__LINE__, disk)) {f.write(TEST_SECOND)}
				assert_nothing_raised(id(__LINE__, disk)) {f.close}
				assert_nothing_raised(id(__LINE__, disk)) {f = disk.fs.fileOpen(TEST_SHORT_FILE, "r")}
				assert_nothing_raised(id(__LINE__, disk)) {f.seek(TEST_FIRST.length)}
				assert_nothing_raised(id(__LINE__, disk)) {buf = f.read}
				assert_nothing_raised(id(__LINE__, disk)) {f.close}
				assert_equal(TEST_SECOND, buf, id(__LINE__, disk))
				assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileDelete(TEST_SHORT_FILE)}
				disk.fs.chdir("/")
				assert_nothing_raised(id(__LINE__, disk)) {disk.fs.dirRmdir(TEST_SHORT_DIR)}
				
				assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileDelete(TEST_LONG_FILE)}
				assert_raise(RuntimeError) {f = disk.fs.fileOpen(TEST_LONG_FILE, "r")}
				assert_nothing_raised(id(__LINE__, disk)) {f = disk.fs.fileOpen(TEST_LONG_FILE, "w")}
				assert_nothing_raised(id(__LINE__, disk)) {f.write(TEST_FIRST)}
				assert_nothing_raised(id(__LINE__, disk)) {f.close}
				assert_nothing_raised(id(__LINE__, disk)) {f = disk.fs.fileOpen(TEST_LONG_FILE, "r")}
				assert_nothing_raised(id(__LINE__, disk)) {buf = f.read}
				assert_nothing_raised(id(__LINE__, disk)) {f.close}
				assert_equal(TEST_FIRST, buf, id(__LINE__, disk))
				assert_nothing_raised(id(__LINE__, disk)) {f = disk.fs.fileOpen(TEST_LONG_FILE, "w")}
				assert_nothing_raised(id(__LINE__, disk)) {f.write(TEST_SECOND)}
				assert_nothing_raised(id(__LINE__, disk)) {f.close}
				assert_nothing_raised(id(__LINE__, disk)) {f = disk.fs.fileOpen(TEST_LONG_FILE, "r")}
				assert_nothing_raised(id(__LINE__, disk)) {buf = f.read}
				assert_nothing_raised(id(__LINE__, disk)) {f.close}
				assert_equal(TEST_SECOND, buf, id(__LINE__, disk))
				assert_nothing_raised(id(__LINE__, disk)) {f = disk.fs.fileOpen(TEST_LONG_FILE, "w")}
				assert_nothing_raised(id(__LINE__, disk)) {f.write(TEST_FIRST)}
				assert_nothing_raised(id(__LINE__, disk)) {f.close}
				assert_nothing_raised(id(__LINE__, disk)) {f = disk.fs.fileOpen(TEST_LONG_FILE, "a")}
				assert_nothing_raised(id(__LINE__, disk)) {f.write(TEST_SECOND)}
				assert_nothing_raised(id(__LINE__, disk)) {f.close}
				assert_nothing_raised(id(__LINE__, disk)) {f = disk.fs.fileOpen(TEST_LONG_FILE, "r")}
				assert_nothing_raised(id(__LINE__, disk)) {f.seek(TEST_FIRST.length)}
				assert_nothing_raised(id(__LINE__, disk)) {buf = f.read}
				assert_nothing_raised(id(__LINE__, disk)) {f.close}
				assert_equal(TEST_SECOND, buf, id(__LINE__, disk))
				assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileDelete(TEST_LONG_FILE)}
			else
				puts "\ntc_fat32_write: FS is nil at line #{__LINE__} on #{disk.info.fileName}"
			end
		end
	end
	
	def test_fat32_span_clusters
		num_tests += 1
		@disks.each do |disk|
			next if disk.nil?
			if disk.fs and disk.bs
				
				# How many entries cover 1.5 clusters.
				num_ents = disk.bs.bytesPerCluster / DIR_ENT_SIZE * 1.5
				
				# Create that many dirs & files then remove them.
				num_ents.times do |idx|
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.dirMkdir("dir" + idx.to_s)}
				end
				num_ents.times do |idx|
					f = nil
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileOpen("file" + idx.to_s)}
					f.close
				end
				num_ents_times do |idx|
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.dirRmdir("dir" + idx.to_s)}
				end
				num_ents_times do |idx|
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileDelete("file" + idx.to_s)}
				end
			end
		end
	end
	
	def id(line, disk)
		return "Failure: Line #{line}, File: #{__FILE__}, Disk: #{disk.info.fileName}"
	end
		
end
