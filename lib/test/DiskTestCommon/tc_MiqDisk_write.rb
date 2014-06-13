require 'ostruct'

$:.push("#{File.dirname(__FILE__)}/..")
require 'VmsFromYaml'

$:.push("#{File.dirname(__FILE__)}/../../disk")
require 'MiqDisk'

class TestMiqDiskWrite < Test::Unit::TestCase
	
	TEST_DB = "#{File.dirname(__FILE__)}/../vms.yml"
	
	def initialize(obj)
		#puts "tc_MiqDisk_write"
		@num_tests = 0
		super(obj)
	end
	
	def test_write
		if $miq_test_write
			@num_tests += 1
			vms = VmsFromYaml.new(TEST_DB)
			@disk_specs = vms.find_vms_with_criteria
			@disk_specs.each do |spec|
				filename = spec['location']
				next unless File.exists?(filename)

				di = OpenStruct.new
				di.fileName = filename
				di.rawDisk = di.fileName.include?('-flat') ? true : false
				dk = MiqDisk.getDisk(di)
				if dk
					dk.getPartitions.each do |pt|
						next if pt.nil?
						#puts "\ntc_MiqDisk_write: Write testing #{di.fileName}"
						4096.times do
							blkSize = rand(2048)
							limit = pt.d_size - blkSize
							adrs = rand(limit)
							pt.seek(adrs)
							original = pt.read(blkSize)
							data = String.new
							blkSize.times {data << [rand(255)].pack('C')}
							pt.seek(adrs)
							pt.write(data, data.size)
							pt.seek(adrs)
							buf = pt.read(blkSize)
							pt.seek(adrs)
							pt.write(original, original.size)
							assert_equal(data, buf)
						end
					end
					res, h = dk.close
					assert_not_equal(h, -1) if h
				else
					puts "\ntc_MiqDisk_write: no disk for #{di.fileName}"
					puts "Spec is:\n#{spec.inspect}"
				end
			end
		end
	end
end