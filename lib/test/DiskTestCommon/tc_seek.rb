require 'test/unit'
require 'ostruct'

$:.push("#{File.dirname(__FILE__)}/..")
require 'VmsFromYaml'

$:.push("#{File.dirname(__FILE__)}/../../disk")
require 'MiqDisk'

$:.push("#{File.dirname(__FILE__)}/../../fs/MiqFS")
require 'MiqFS'

class TestSeek < Test::Unit::TestCase
	
	TEST_DB = "#{File.dirname(__FILE__)}/../vms.yml"
	TEST_FILE = '/SeekTest.dat'
	
	def initialize(obj)
		#puts "tc_seek"
		@num_tests = 0
		super(obj)
	end
	
	def setup
		vms = VmsFromYaml.new(TEST_DB)
		@disk_specs = vms.find_vms_with_criteria
		@disks = Array.new
		@disk_specs.each do |spec|
			filename = spec['location']
			next unless File.exist?(filename)

			di = OpenStruct.new
			di.fileName = filename
			di.rawDisk = di.fileName.include?('-flat') ? true : false
			dk = MiqDisk.getDisk(di)
			if dk
				thisDisk = OpenStruct.new('info' => di, 'disk' => dk)
				thisDisk.fs = MiqFS.getFS(dk.getPartitions[spec['vm_system_partition']])
				@disks << thisDisk
			else
				@disks << nil
				puts "\ntc_seek: no disk for #{di.fileName}"
				puts "Spec is:\n#{spec.inspect}"
			end
		end
	end
	
	def teardown
		@disks.each do |disk|
			next if disk.nil?
			res, h = disk.dk.close if disk.dk
			assert_not_equal(h, -1) if h
		end
	end
	
	def test_random_seek
		@num_tests += 1
		@disks.each do |disk|
			if disk.fs
				#puts "\ntc_seek: Seek testing #{disk.info.fileName}"
				if disk.fs.fileExists?(TEST_FILE)
					f = disk.fs.fileOpen(TEST_FILE, "r")
					# Do 10,000 random seeks.
					10000.times do
						pos = rand(65534)
						f.seek(pos * 2)
						got = f.read(2).unpack("S")[0]
						assert_equal(pos, got)
					end
					f.close
				else
					puts "\ntc_seek: Seek test file is not on disk #{disk.info.fileName}"
				end
			end
		end
	end
	
end
