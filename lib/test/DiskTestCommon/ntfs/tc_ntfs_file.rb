require 'test/unit'
require 'ostruct'

$:.push("#{File.dirname(__FILE__)}/../..")
require 'VmsFromYaml'

$:.push("#{File.dirname(__FILE__)}/../../../disk")
require 'MiqDisk'

$:.push("#{File.dirname(__FILE__)}/../../../fs/MiqFS")
require 'MiqFS'

$:.push("#{File.dirname(__FILE__)}/..")
require 'FSTestUtil'

class NtfsTestFile < Test::Unit::TestCase
	
	CONDITIONS = ['fs_type', 'ntfs']
	TEST_DB = "#{File.dirname(__FILE__)}/../../vms.yml"
		
	def initialize(obj)
		#puts "NTFS:tc_ntfs_file"
		@num_tests = 0
		super(obj)
	end
	
	def setup
		vms = VmsFromYaml.new(TEST_DB)
		@disk_specs = vms.find_vms_with_criteria(CONDITIONS)
		#puts "NTFS:tc_ntfs_file:setup found #{@disk_specs.size} VMs"
		@disks = Array.new
		@disk_specs.each do |spec|
			filename = spec['location']
			next unless File.exist?(filename)
			
			di = OpenStruct.new
			di.fileName = filename
			di.rawDisk = di.fileName.include?('-flat') ? true : false
			dk = MiqDisk.getDisk(di)
			if dk
				thisDisk = OpenStruct.new('info' => di, 'dk' => dk)
				thisDisk.fs = MiqFS.getFS(dk.getPartitions[spec['vm_system_partition']])
				thisDisk.sy = FSTestUtil.lookSystemDir(thisDisk.fs)
				thisDisk.sy = '/windows' if thisDisk.sy.nil?
				@disks << thisDisk
			else
				@disks << nil
				puts "\ntc_ntfs_file: no disk for #{di.fileName}"
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
	
	def test_ntfs_file_files
		@num_tests += 1
		@disks.each do |disk|
			next if disk.nil?
			if disk.fs
				#puts "\ntc_ntfs_file: Testing files on #{disk.info.fileName}"
				disk.fs.chdir(disk.sy)
				disk.fs.dirGlob("*.ini") do |f|
					fo = disk.fs.fileOpen(f)
					assert_nothing_raised(id(__LINE__, disk)) {fo.read}
					assert_nothing_raised(id(__LINE__, disk)) {fo.close}
				end
			else
				puts "\ntc_ntfs_file: FS is nil at line #{__LINE__} on #{disk.info.fileName}"
			end
		end
	end
	
	def test_ntfs_file_attribs
		@num_tests += 1
		@disks.each do |disk|
			next if disk.nil?
			if disk.fs
				# By file.
				#puts "\ntc_ntfs_file: Testing file attributes on #{disk.info.fileName}"
				disk.fs.dirGlob("#{disk.sy}/system32/*.exe") do |f|
					assert_equal(true, disk.fs.fileExists?(f), id(__LINE__, disk))
					assert_equal(false, disk.fs.fileDirectory?(f), id(__LINE__, disk))
					assert_equal(true, disk.fs.fileFile?(f), id(__LINE__, disk))
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileSize(f)}
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileAtime(f)}
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileCtime(f)}
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileMtime(f)}
					
					# By object.
					disk.fs.fileOpen(f) do |fo|
						assert_nothing_raised(id(__LINE__, disk)) {fo.atime}
						assert_nothing_raised(id(__LINE__, disk)) {fo.ctime}
						assert_nothing_raised(id(__LINE__, disk)) {fo.mtime}
						assert_nothing_raised(id(__LINE__, disk)) {fo.size}
					end
				end
			else
				puts "\ntc_ntfs_file: FS is nil at line #{__LINE__} on #{disk.info.fileName}"
			end
		end
		end
	
	def test_ntfs_file_locations
		@num_tests += 1
		@disks.each do |disk|
			next if disk.nil?
			if disk.fs
				#puts "\ntc_ntfs_file: Testing file locations on #{disk.info.fileName}"
				# Check a number of locations. Get some root, some shallow and some deep.
				names = [
					"#{disk.sy}/system32",
					"#{disk.sy}/system32/config",
					"/DocuMENTS aNd settINGS/All Users",
					"/Documents and Settings/Osama Been Hiden",
					"#{disk.sy}/bootstat.dat",
					"/program files/common files/microsoft shared/wmi",
					"#{disk.sy}/system32/drivers/etc/hosts"
				]
				names.each do |name|
					puts "looking for #{name} on #{disk.info.fileName}"
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileExists?(name)}
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileDirectory?(name)}
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileFile?(name)}
				end
			else
				puts "\ntc_ntfs_file: FS is nil at line #{__LINE__} on #{disk.info.fileName}"
			end
		end
	end
	
	def test_ntfs_file_root
		@num_tests += 1
		@disks.each do |disk|
			next if disk.nil?
			if disk.fs
				#puts "\ntc_ntfs_file: Testing root directory on #{disk.info.fileName}"
				assert_equal("NTFS", disk.fs.fsType, id(__FILE__, disk))
				assert_nothing_raised(id(__LINE__, disk)) {disk.fs.dirEntries(disk.fs.pwd)}
			else
				puts "\ntc_ntfs_file: FS is nil at line #{__LINE__} on #{disk.info.fileName}"
			end
		end
	end
	
	def id(line, disk)
		return "Failure: Line #{line}, File: #{__FILE__}, Disk: #{disk.info.fileName}"
	end
end
