require 'test/unit'
require 'ostruct'

require 'FSTestUtil'

$:.push("#{File.dirname(__FILE__)}/..")
require 'VmsFromYaml'

$:.push("#{File.dirname(__FILE__)}/../../disk")
require 'MiqDisk'

$:.push("#{File.dirname(__FILE__)}/../../fs/MiqFS")
require 'MiqFS'

# WINDOWS SPECIFIC.
class TestReg < Test::Unit::TestCase
	
	#define registry structures
	REGISTRY_HEADER_REGF = BinaryStruct.new([
		'a4',       'id',                # /* ASCII "regf" = 0x66676572    */
		'i',        'updates1',          # /* update counter 1             */
		'i',        'updates2',          # /* update counter 2             */
		'Q',        'timestamp',         # /* last modified (WinNT format) */
		'i',        'version-major',     # /* Version - Major Number       */
		'i',        'version-minor',     # /* Version - Minor Number       */
		'i',        'version-release',   # /* Version - Release Number     */
		'i',        'version-build',     # /* Version - Build Number       */
		'i',        'data_offset',       # /* Data offset                  */
		'i',        'last_block',        # /* Offset of Last Block         */
		'i',        nil,                 # /* UNKNOWN for 4  =1            */
		'a64',      'name',              # /* description - last 31 characters of Fully Qualified Hive Name (in Unicode) */
		'a396',     nil,                 # /* UNKNOWN x396                 */
		'i',        'checksum',          # /* checksum of all DWORDS (XORed) from 0x0000 to 0x01FB */
	])

	REGISTRY_STRUCT_HBIN = BinaryStruct.new([
		'a4',       'id',                # /* ASCII "hbin" = 0x6E696268          */
		'i',        'offset_from_first', # /* Offset from 1st hbin-Block         */
		'i',        'offset_to_next',    # /* Offset to the next hbin-Block      */
		'Q',        nil,                 # /* UNKNOWN for 8                      */
		'Q',        'timestamp',         # /* last modified (WinNT format)       */
		'i',        'block_size',        # /* Block size (including the header!) */
		'l',        'length',            # /* Negative if not used, positive otherwise.  Always a multiple of 8 */
	])
	
	CONDITIONS = ['os_type', 'windows']
	TEST_DB = "#{File.dirname(__FILE__)}/../vms.yml"
	
	def initialize(obj)
		#puts "tc_vfyreg"
		@num_tests = 0
		super(obj)
	end
	
	def setup
		vms = VmsFromYaml.new(TEST_DB)
		@disk_specs = vms.find_vms_with_criteria(CONDITIONS)
		@disks = Array.new
		@disk_specs.each do |spec|
			filename = spec['location']
			next unless File.exists?(filename)

			di = OpenStruct.new
			di.fileName = filename
			di.rawDisk = di.fileName.include?('-flat') ? true : false
			dk = MiqDisk.getDisk(di)
			if dk
				thisDisk = OpenStruct.new('info' => di, 'disk' => dk)
				thisDisk.fs = MiqFS.getFS(dk.getPartitions[spec['vm_system_partition']])
				thisDisk.sy = FSTestUtil.lookSystemDir(thisDisk.fs)
				thisDisk.sy = "/windows" if thisDisk.sy.nil?
				@disks << thisDisk
			else
				@disks << nil
				puts "\ntc_vfyreg: no disk for #{di.fileName}"
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
	
	def test_hives
		@disks.each do |disk|
			next if disk.nil?
			if disk.fs
				#puts "\ntc_vfyreg: Testing registry hives on #{disk.info.fileName}"
				%w[sam security software system default].each do |hive|
					fn = disk.sy + "/system32/config/" + hive
					
					# Perform basic checks
					puts disk.info.fileName
					if not disk.fs.fileExists?(fn)
						puts "Registry file [#{fn}] does not exist.\nFile: #{disk.info.fileName}"
						next
					end
					if disk.fs.fileSize(fn) == 0
						puts "Registry file [#{fn}] is empty.\nFile: #{disk.info.fileName}"
						next
					end
					hFile = disk.fs.fileOpen(fn)
					raise "Registry file [#{fn}] does not contain valid marker." if hFile.read(4) != "regf"
					hFile.seek(0)
					
					# Read in Registry header
					head_string = hFile.read(REGISTRY_HEADER_REGF.size)
					raise "No header!" unless head_string
					@hiveHash = REGISTRY_HEADER_REGF.decode(head_string)
					
					# Get all data & verify hive.
					hFile.seek(0)
					hiveBuf = hFile.read()
					hFile.close
					ValidateHBins(hiveBuf)
				end
			else
				puts "\ntc_vfyreg: FS is nil for #{disk.info.fileName}"
			end
		end
	end
	
	def ValidateHBins(hiveBuf)
		if @fs
			offset = 0x1000
			head_string = hiveBuf[offset..(offset + REGISTRY_STRUCT_HBIN.size)]
			raise "No header!" unless head_string
			binHash = REGISTRY_STRUCT_HBIN.decode(head_string)
			while (binHash["offset_to_next"] + binHash["offset_from_first"]) < @hiveHash["last_block"] do
				print "."
				raise "Registry failed during HBin validation" unless binHash["id"] == "hbin"
				# Read the next hbin into memory and decode the header
				offset += binHash["offset_to_next"]
				head_string = hiveBuf[offset..(offset + REGISTRY_STRUCT_HBIN.size)]
				binHash = REGISTRY_STRUCT_HBIN.decode(head_string)
			end
		end
	end
end