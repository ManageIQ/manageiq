require 'ostruct'

$:.push("#{File.dirname(__FILE__)}/..")
require 'VmsFromYaml'

$:.push("#{File.dirname(__FILE__)}/../../disk")
require 'MiqDisk'

class TestMiqDiskReadLen < Test::Unit::TestCase
	
	TEST_DB = "#{File.dirname(__FILE__)}/../vms.yml"	
	
	def initialize(obj)
		#puts "tc_MiqDisk_read_length"
		@num_tests = 0
		super(obj)
	end
	
	def test_read_length
		@num_tests += 1
		vms = VmsFromYaml.new(TEST_DB)
		@disk_specs = vms.find_vms_with_criteria
		@disk_specs.each do |spec|
			filename = spec['location']
			next unless File.exist?(filename)

			di = OpenStruct.new
			di.fileName = filename
			di.rawDisk = di.fileName.include?('-flat') ? true : false
			dk = MiqDisk.getDisk(di)
			if dk
				dk.getPartitions.each do |pt|
					next if pt.nil?
					#puts "\ntc_MiqDisk_read_length: Testing read length on #{di.fileName}"
					4096.times do
						blkSize = rand(2048)
						limit = pt.d_size - blkSize
						adrs = rand(limit)
						pt.seek(adrs)
						data = pt.read(blkSize)
						assert_equal(blkSize, data.size)
					end
				end
				res, h = dk.close
				assert_not_equal(h, -1) if h
			else
				puts "\ntc_MiqDisk_read_length: no disk for #{di.fileName}"
				puts "Spec is:\n#{spec.inspect}"
			end
		end
	end
end
