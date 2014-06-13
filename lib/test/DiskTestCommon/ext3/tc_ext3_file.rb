require 'ostruct'

$:.push("#{File.dirname(__FILE__)}/../..")
require 'VmsFromYaml'

$:.push("#{File.dirname(__FILE__)}/../../../disk")
require 'MiqDisk'

$:.push("#{File.dirname(__FILE__)}/../../../fs/MiqFS")
require 'MiqFS'

class Ext3TestFile < Test::Unit::TestCase
	
	CONDITIONS = ['fs_type', 'ext3']
	TEST_DB = "#{File.dirname(__FILE__)}/../../vms.yml"
		
	def initialize(obj)
		#puts "Ext3:tc_ext3_file"
		@num_tests = 0
		super(obj)
	end
	
	def setup
		vms = VmsFromYaml.new(TEST_DB)
		@disk_specs = vms.find_vms_with_criteria(CONDITIONS)
		#puts "Ext3:tc_ext3_file:setup found #{@disk_specs.size} VMs"
		@disks = Array.new
		@disk_specs.each do |spec|
			di = OpenStruct.new
			di.fileName = spec['location']
			di.rawDisk = di.fileName.include?('-flat') ? true : false
			dk = MiqDisk.getDisk(di)
			if dk
				thisDisk = OpenStruct.new('info' => di, 'dk' => dk)
				thisDisk.fs = MiqFS.getFS(dk.getPartitions[spec['vm_system_partition']])
				@disks << thisDisk
			else
				@disks << nil
				puts "\ntc_ext3_file: no disk for #{di.fileName}"
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
	
	def test_ext3_file_directories
		@num_tests += 1
		@disks.each do |disk|
			next if disk.nil?
			if disk.fs
				#puts "\nExt3: Testing file locations on #{disk.info.fileName}"
				%w[/bin /usr/bin /usr/lib].each {|dir|
					if disk.fs.fileDirectory?(dir)
						assert_nothing_raised(id(__LINE__, disk)) {disk.fs.chdir(dir)}
						assert_nothing_raised(id(__LINE__, disk)) {disk.fs.dirGlob("*")}
					end
				}
			else
				puts "\ntc_ext3_file: FS is nil at line #{__LINE__} on #{disk.info.fileName}"
			end
		end
	end
	
	def test_ext3_file_files
		@num_tests += 1
		@disks.each do |disk|
			next if disk.nil?
			if disk.fs
				#puts "\nExt3: Testing files on #{disk.info.fileName}"
				%w[/etc/passwd /etc/fstab].each {|file|
					f = nil
					assert_nothing_raised(id(__LINE__, disk)) {f = disk.fs.fileOpen(file)}
					assert_nothing_raised(id(__LINE__, disk)) {f.read}
					f.close
				}
			else
				puts "\ntc_ext3_file: FS is nil at line #{__LINE__} on #{disk.info.fileName}"
			end
		end
	end
	
	def test_ext3_file_root_files
		@num_tests += 1
		@disks.each do |disk|
			next if disk.nil?
			if disk.fs
				#puts "\nExt3: Testing root directory on #{disk.info.fileName}"
				disk.fs.chdir("/")
				disk.fs.dirGlob("*") {|name|
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileCtime(name)}
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileAtime(name)}
					assert_nothing_raised(id(__LINE__, disk)) {disk.fs.fileMtime(name)}
					if disk.fs.fileFile?(name)
						f = nil
						#puts name
						assert_nothing_raised(id(__LINE__, disk)) {f = disk.fs.fileOpen(name)}
						
						# We want to log instances of bad file objects, but not blow up entirely.
						# The Cruise Control Build Log will show these errors.
						if f.respond_to?(:fileCtime)
							assert_nothing_raised(id(__LINE__, disk)) {f.fileCtime}
							assert_nothing_raised(id(__LINE__, disk)) {f.fileAtime}
							assert_nothing_raised(id(__LINE__, disk)) {f.fileMtime}
							assert_equal(f.size, disk.fs.fileSize(name), id(__LINE__, disk))
							assert_equal(f.size, f.read.size, id(__LINE__, disk))
						else
							puts "\nOpen succeeded but file object is bad"
							puts disk.info.fileName
							puts File.join(disk.fs.pwd, name)
							puts "\n"
						end
						
						f.close if f
					end
				}
			else
				puts "\ntc_ext3_file: FS is nil at line #{__LINE__} on #{disk.info.fileName}"
			end
		end
	end
	
	def id(line, disk)
		return "Failure: Line #{line}, File: #{__FILE__}, Disk: #{disk.info.fileName}"
	end
end
