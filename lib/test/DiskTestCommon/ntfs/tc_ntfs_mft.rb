require 'test/unit'
require 'ostruct'

$:.push("#{File.dirname(__FILE__)}/../..")
require 'VmsFromYaml'

$:.push("#{File.dirname(__FILE__)}/../../../disk")
require 'MiqDisk'

$:.push("#{File.dirname(__FILE__)}/../../../fs/ntfs")
require 'NtfsBootSect'
require 'NtfsMftEntry'

# NOTE: This version of initialize is used to:
#   Load an entry with HEADER ONLY first.
#   If this is not an extended entry or deleted, THEN go ahead and process attributes.
class MftEntry
	def initialize(bs, recordNumber = 0, baseMFT = nil, full_rec = true)
		raise "Nil boot sector" if bs == nil
		
    @indexRoot  = @dataRoot = @attribData = nil
    @baseMFT    = baseMFT || self
    @attribs    = Array.new
		
		# Buffer boot sector & seek to requested record.
		@boot_sector = bs
		bs.stream.seek(bs.mftRecToBytePos(recordNumber))
    
		# Get & decode the FILE_RECORD.
		@buf       = bs.stream.read(bs.bytesPerFileRec)
		@mft_entry = FILE_RECORD.decode(@buf)
		
		# Bail now if we only want headers. This is for testing only.
		return if not full_rec
		
		# FB 2991
		raise "Uninitialized MFT Entry <#{recordNumber}>" if @mft_entry['signature'] == "\000\000\000\000"
		
		# Adjust for older versions (don't have unused1 and mft_rec_num).
		version = bs.version
		if version != nil && version < 4.0
			@mft_entry['fixup_seq_num'] = @mft_entry['unused1']
			@mft_entry['mft_rec_num']   = recordNumber
		end
		
		# Set accessor data.
		@sequenceNum = @mft_entry['seq_num']
		@recNum      = @mft_entry['mft_rec_num']
    
		# Validate the sector data
		raise "Invalid MFT Entry <#{@recNum}>" if fixUp() == false
		
		@buf = @buf[@mft_entry['offset_to_attrib']..-1]
		populateAttribHeaders
		getAttrib(AT_INDEX_ROOT)
    getAttrib(AT_BITMAP) if @recNum > 0
		getAttrib(AT_INDEX_ALLOCATION)
		getAttrib(AT_ATTRIBUTE_LIST)
	end
end

class NtfsTestMft < Test::Unit::TestCase
	
	CONDITIONS = ['fs_type', 'ntfs']
	TEST_DB = "#{File.dirname(__FILE__)}/../../vms.yml"
		
	def initialize(obj)
		#puts "NTFS:tc_ntfs_mft"
		@num_tests = 0
		super(obj)
	end
	
	def test_ntfs_mft_entry
		if $miq_test_deep
			@num_tests += 1
			vms = VmsFromYaml.new(TEST_DB)
			@disk_specs = vms.find_vms_with_criteria(CONDITIONS)
			#puts "NTFS:tc_ntfs_mft:test_ntfs_mft_entry found #{@disk_specs.size} VMs"
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
					puts "\ntc_ntfs_mft: no disk for #{di.fileName}"
					puts "Spec is:\n#{spec.inspect}"
				end
			end
			
			@disks.each do |disk|
				next if disk.nil?
				#puts "\ntc_ntfs_mft: Testing MFT entries on #{disk.info.fileName}"
				assert_instance_of(MiqDisk, disk.pt, id(__LINE__, disk))
				bs = NTFS::BootSect.new(disk.pt)
				assert_instance_of(NTFS::BootSect, bs, id(__LINE__, disk))
				#puts "tc_ntfs_mft: Boot sector confirmed\n\n"
				
				# Read MFT.
				#puts "Testing #{bs.maxMft} MFT records..."
				12.upto(bs.maxMft) {|rec|
					mh = nil #mh is mft_entry_header
					# Load HEADER ONLY first.
					assert_nothing_raised(id(__LINE__, disk)) {mh = NTFS::MftEntry.new(bs, rec, nil, false)}
					next if mh.isDeleted?
					next if NtUtil.MkRef(mh.mft_entry['ref_to_base_file_rec'])[1] != 0
					next if mh.mft_entry['signature'] == "\000\000\000\000"
					# If this is not an extended entry or deleted, continue...
					#assert_equal(rec.to_s, mh.to_s)
					me = nil #me is full mft_entry
					assert_nothing_raised(id(__LINE__, disk)) {me = NTFS::MftEntry.new(bs, rec)}
					assert(me.attribs.size > 0, "Attribute list shouldn't be empty")
				}
				#puts "#{used} records are in use."
				res, h = disk.dk.close if disk.dk
				if h
					puts "Got an invalid handle back from close on #{disk.info.fileName} in #{__FILE__}" if h == -1
				end
			end
		end
	end
	
	def test_emtpy
		@num_tests += 1
		assert_raise(RuntimeError) {NTFS::MftEntry.new(nil, nil)}
	end
	
	def id(line, disk)
		return "Failure: Line #{line}, File: #{__FILE__}, Disk: #{disk.info.fileName}"
	end
end
