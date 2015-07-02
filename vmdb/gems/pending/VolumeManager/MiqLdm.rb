# encoding: US-ASCII

# Windows dynamic disks
#

$:.push("#{File.dirname(__FILE__)}/../util")

require 'ostruct'
require 'binary_struct'
require 'miq-uuid'

class BinaryStruct
	
	def BinaryStruct.stepDecode(data, format)
		type = format[0,1]
		raise "unrecognized format: #{type}" if SIZES.has_key?(type) == false
		raise "unsupported  format: #{type}" if SIZES[type] == nil

		count = (format.size > 1) ? format[1,format.size-1].to_i : 1
		raise "unsupported count: #{count}" if count.kind_of?(Numeric)  == false

		size = (count * SIZES[type])
		
		data.slice!(0, size).unpack(format)[0]
	end
	
end

module LdmScanner
	
	LDM_SECTOR_SIZE		= 512
	LDM_PARTITION_TYPE  = 66
	PRIVHEAD_OFFSET		= 6 * LDM_SECTOR_SIZE
	
	#
	# On disk, all numbers are in big-endian format.
	#
	
	PRIVHEAD	= [
		'a8',			'signature',			# 8
		'N',			'unknown_1',			# 4
		'n',			'ver_major',			# 2
		'n',			'ver_minor',			# 2
		'Q',			'timestamp',			# 8
		'Q',			'unknown_2',			# 8 number ?
		'Q',			'unknown_3',			# 8 size ?
		'Q',			'unknown_4',			# 8 size ?
		'a64',			'disk_id',				# 64 zero padded
		'a64',			'host_id',				# 64 zero padded
		'a64',			'diskgroup_id',			# 64 zero padded
		'a32',			'diskgroup_name',		# 32 zero padded
		'a2',			'unknown_5',			# 2
		'a9',			'unknown_6',			# 9 zeros
		'N',			'logical_disk_start_H',	# 8
		'N',			'logical_disk_start_L',	# "
		'N',			'logical_disk_size_H',	# 8
		'N',			'logical_disk_size_L',	# "
		'N',			'db_start_H',			# 8
		'N',			'db_start_L',			# "
		'N',			'db_size_H',			# 8
		'N',			'db_size_L',			# "
		'N',			'num_tocs_H',			# 8
		'N',			'num_tocs_L',			# "
		'N',			'toc_size_H',			# 8
		'N',			'toc_size_L',			# "
		'N',			'num_configs',			# 4
		'N',			'num_logs',				# 4
		'N',			'config_size_H',		# 8
		'N',			'config_size_L',		# "
		'N',			'log_size_H',			# 8
		'N',			'log_size_L',			# "
		'N',			'disk_signature',		# 4
		'C16',			'disk_set_guid',		# 16
		'C16',			'disk_set_guid2',		# 16
		"C#{512-391}",	'padding'				# Pad to 512 bytes (sector size)
	]
	
	TBLOCK_BLOCK	= [ 1, 2, 2045, 2046 ]
	TOCBLOCK	= [
		'a8',			'signature',
		'N',			'sequence1',
		'a4',			'unknown1',
		'N',			'sequence2',
		'a16',			'unknown2',
		'a10',			'bitmap1_name',
		'N',			'bitmap1_start_H',
		'N',			'bitmap1_start_L',
		'N',			'bitmap1_size_H',
		'N',			'bitmap1_size_L',
		'N',			'bitmap1_flags_H',
		'N',			'bitmap1_flags_L',
		'a10',			'bitmap2_name',
		'N',			'bitmap2_start_H',
		'N',			'bitmap2_start_L',
		'N',			'bitmap2_size_H',
		'N',			'bitmap2_size_L',
		'N',			'bitmap2_flags_H',
		'N',			'bitmap2_flags_L',
		"C#{512-104}",	'padding'
	]
	
	VMDB	= [
		'a4',			'signature',
		'N',			'sequence',
		'N',			'vblk_size',
		'N',			'vblk_offset',
		'n',			'unknown1',
		'n',			'ver_major',
		'n',			'ver_minor',
		'a31',			'dg_name',
		'a64',			'dg_guid',
		'N',			'committed_seq_H',
		'N',			'committed_seq_L',
		'N',			'pending_seq_H',
		'N',			'pending_seq_L',
		'a56',			'unknown2',
		'N',			'timestamp',
		"C#{512-193}",	'padding'
	]
	
	VBLK	= [
		'a4',			'signature',
		'N',			'vmdb_seq',
		'N',			'grpnum',
		'n',			'record',
		'n',			'nrecords',
		'n',			'update_status',
		'C',			'flags',
		'C',			'rec_type',
		'N',			'data_length',
		"a#{128-24}",	'padding'
	]
	
	#
	# VBLOCK types.
	#
	VBT_NONE		= 0x00
	VBT_COMPONENT	= 0x32
	VBT_PARTITION	= 0x33
	VBT_DISKV1		= 0x34
	VBT_DISKGROUPV1	= 0x35
	VBT_DISKV2		= 0x44
	VBT_DISKGROUPV2	= 0x45
	VBT_VOLUME		= 0x51
	
	VBLK_TYPES	= {
		VBT_NONE		=> "NONE",
		VBT_COMPONENT	=> "Component",
		VBT_PARTITION	=> "Partition",
		VBT_DISKV1		=> "Disk v1",
		VBT_DISKGROUPV1	=> "Disk Group v1",
		VBT_DISKV2		=> "Disk v2",
		VBT_DISKGROUPV2	=> "Disk Group v2",
		VBT_VOLUME		=> "Volume"	
	}
	
	def self.scan(d)
		return nil if d.partType != LDM_PARTITION_TYPE
		
		d.seek(PRIVHEAD_OFFSET)
		ph = readStruct(d, PRIVHEAD)
		# LdmScanner.dumpPrivhead(ph)
		return nil if ph.signature != "PRIVHEAD"
		
		ph.disk_id.delete!("\000")
		ph.diskgroup_id.delete!("\000")
		ph.diskgroup_name.delete!("\000")
		ph.host_id.delete!("\000")
		
		ph.lvm_type = "LDM"
		ph.pv_uuid = ph.disk_id
		ph.diskObj = d
		
		tb = nil
		TBLOCK_BLOCK.each do |tbo|
			tblock_offset = (ph.db_start + tbo) * LDM_SECTOR_SIZE
			d.seek(tblock_offset)
			tb = readStruct(d, TOCBLOCK)
			# LdmScanner.dumpTocblock(tb)
			break if tb.signature == "TOCBLOCK"
		end
		
		if !tb
			$log.warn "LdmScanner: could not find valid TOCBLOCK on LDM disk" if $log
			return nil
		end

		vmdb_offset = (ph.db_start + tb.bitmap1_start) * LDM_SECTOR_SIZE
		d.seek(vmdb_offset)
		vmdb = readStruct(d, VMDB)
		
		ph.vblkHash = {}
		ph.volumes  = []
		ph.diskVb	= nil
		(0...vmdb.sequence).each { |i| readVBLK(d, ph) }

		ph.vblkHash.each_value do |v|
			ph.vblkHash[v.parent_id].children << v if v.parent_id
			v.disk = ph.vblkHash[v.disk_id] if v.disk_id
		end
		return(ph)
	end
	
	def self.readStruct(d, struct)
		h = BinaryStruct.decode(d.read(BinaryStruct.sizeof(struct)), struct)
		h.keys.delete_if { |k| !(/.*_H/ =~ k) }.each do |k|
			(nk = k.dup)[/_H$/] = ""
			lk = nk + "_L"
			h[nk] = (h[k] << 32) | h[lk]
		end
        return OpenStruct.new(h)
    end # def self.readStruct

	def self.getChunk(data)
		len = data.slice!(0, 1).unpack("C")[0]
		data.slice!(0, len)
	end
	
	def self.getNum(data)
		n = 0
		getChunk(data).each_byte { |b| n = (n << 8) | b }
		return(n)
	end
	
	def self.getNBO8(data)
		h, l = data.slice!(0, 8).unpack("N2")
		return((h << 32) | l)
	end
	
	def self.readVBLK(disk, ph)
		vblk = LdmScanner.readStruct(disk, LdmScanner::VBLK)
		return if vblk.data_length == 0
		buf = vblk.padding
		
		vblk.vobject_id		= getNum(buf)
		vblk.name			= getChunk(buf)
		
		case vblk.rec_type
		when VBT_NONE			# NONE
		when VBT_COMPONENT		# Component
			vblk.children		= []
			vblk.volume_state	= getChunk(buf)
			vblk.component_type	= BinaryStruct.stepDecode(buf, "C")
								  BinaryStruct.stepDecode(buf, "C4")
			vblk.num_children	= getNum(buf)
								  BinaryStruct.stepDecode(buf, "C16")
			vblk.parent_id		= getNum(buf)
								  BinaryStruct.stepDecode(buf, "C")
			if vblk.flags != 0
				vblk.stripe_size	= getNum(buf)
				vblk.num_col		= getNum(buf)
			end
			
		when VBT_PARTITION		# Partition
								  BinaryStruct.stepDecode(buf, "C12")
			vblk.start			= getNBO8(buf)
			vblk.volume_offset	= getNBO8(buf)
			vblk.size			= getNum(buf)
			vblk.parent_id		= getNum(buf)
			vblk.disk_id		= getNum(buf)
			vblk.comp_part_idx	= getNum(buf) if vblk.flags == 0x08
			
		when VBT_DISKV1			# Disk v1
			vblk.disk_guid		= getChunk(buf)
			vblk.alt_name		= getChunk(buf)
			ph.diskVb			= vblk if ph.disk_id == vblk.disk_guid
			
		when VBT_DISKGROUPV1	# Disk Group v1
			vblk.dg_guid		= getChunk(buf)
			
		when VBT_DISKV2			# Disk v2
			vblk.disk_guid1		= MiqUUID.parse_raw(BinaryStruct.stepDecode(buf, "a16")).to_s
			vblk.disk_guid2		= MiqUUID.parse_raw(BinaryStruct.stepDecode(buf, "a16")).to_s
			ph.diskVb			= vblk if ph.disk_id == vblk.disk_guid1
			
		when VBT_DISKGROUPV2	# Disk Group v2
			vblk.dg_guid		= MiqUUID.parse_raw(BinaryStruct.stepDecode(buf, "a16")).to_s
			vblk.ds_guid		= MiqUUID.parse_raw(BinaryStruct.stepDecode(buf, "a16")).to_s
			
		when VBT_VOLUME			# Volume
			vblk.children		= []
			vblk.volume_type	= getChunk(buf)
								  BinaryStruct.stepDecode(buf, "C")
			vblk.volume_state	= BinaryStruct.stepDecode(buf, "a14").delete("\000")
			vblk.volume_typeN	= BinaryStruct.stepDecode(buf, "C")
								  BinaryStruct.stepDecode(buf, "C")
			vblk.volume_number	= BinaryStruct.stepDecode(buf, "C")
								  BinaryStruct.stepDecode(buf, "C3")
			vblk.vol_flags		= BinaryStruct.stepDecode(buf, "C")
			vblk.num_children	= getNum(buf)
								  BinaryStruct.stepDecode(buf, "C16")
			vblk.size			= getNum(buf)
								  BinaryStruct.stepDecode(buf, "C4")
			vblk.partition_type	= BinaryStruct.stepDecode(buf, "C")
			vblk.volume_id		= MiqUUID.parse_raw(BinaryStruct.stepDecode(buf, "a16")).to_s
			
			vblk.id1			= getChunk(buf)	if (vblk.flags & 0x08) != 0x0
			vblk.id2			= getChunk(buf)	if (vblk.flags & 0x20) != 0x0
			vblk.csize			= getNum(buf)	if (vblk.flags & 0x80) != 0x0
			vblk.drive_hint		= getChunk(buf)	if (vblk.flags & 0x02) != 0x0
			
			if vblk.volume_state == "ACTIVE"
				if vblk.volume_type == "gen"
					ph.volumes << vblk
				else
					$log.warn "LdmScanner: unsupported volume type - #{vblk.volume_type}" if $log
				end
			end
		end
		
		vblk.delete_field("padding") if vblk.padding
		ph.vblkHash[vblk.vobject_id] = vblk
		return(vblk)
	end

	def self.dumpPrivhead(ph)
		puts
		puts "PRIVHEAD:"
		puts "\tsignature:          #{ph.signature}"
		puts "\tver_major:          #{ph.ver_major}"
		puts "\tver_minor:          #{ph.ver_minor}"
		puts "\tdisk_id:            #{ph.disk_id}"
		puts "\thost_id:            #{ph.host_id}"
		puts "\tdiskgroup_id:       #{ph.diskgroup_id}"
		puts "\tdiskgroup_name:     #{ph.diskgroup_name}"
		puts "\tlogical_disk_start: #{ph.logical_disk_start}"
		puts "\tlogical_disk_size:  #{ph.logical_disk_size}"
		puts "\tdb_start:           #{ph.db_start}"
		puts "\tdb_size:            #{ph.db_size}"
		puts "\tnum_tocs:           #{ph.num_tocs}"
		puts "\ttoc_size:           #{ph.toc_size}"
		puts "\tnum_configs:        #{ph.num_configs}"
		puts "\tconfig_size:        #{ph.config_size}"
		puts "\tnum_logs:           #{ph.num_logs}"
		puts "\tlog_size:           #{ph.log_size}"
		puts "\tdisk_signature:     #{ph.disk_signature}"
		puts "\tdisk_set_guid:      #{ph.disk_set_guid}"
		puts "\tdisk_set_guid2:     #{ph.disk_set_guid2}"
	end
	
	def self.dumpTocblock(tb)
		puts
		puts "TOCBLOCK:"
		puts "\tsignature:          #{tb.signature}"
		puts "\tsequence1:          #{tb.sequence1}"
		puts "\tsequence2:          #{tb.sequence2}"
		puts "\tbitmap1_name:       #{tb.bitmap1_name}"
		puts "\tbitmap1_start:      #{tb.bitmap1_start}"
		puts "\tbitmap2_name:       #{tb.bitmap2_name}"
		puts "\tbitmap2_start:      #{tb.bitmap2_start}"
	end
	
	def self.dumpVmdb(vmdb)
		puts
		puts "VMDB:"
		puts "\tsignature:          #{vmdb.signature}"
		puts "\tsequence:           #{vmdb.sequence}"
		puts "\tvblk_size:          #{vmdb.vblk_size}"
		puts "\tvblk_offset:        #{vmdb.vblk_offset}"
		puts "\tver_major:          #{vmdb.ver_major}"
		puts "\tver_minor:          #{vmdb.ver_minor}"
		puts "\tdg_name:            #{vmdb.dg_name}"
		puts "\tdg_guid:            #{vmdb.dg_guid}"
		puts "\tcommitted_seq:      #{vmdb.committed_seq}"
		puts "\tpending_seq:        #{vmdb.pending_seq}"
	end
	
	def self.dumpVblk_old(vb)
		return if vb.data_length == 0
		puts
		puts "VBLK:"
		puts   "\tsignature:          #{vb.signature}"
		puts   "\tvmdb_seq:           #{vb.vmdb_seq}"
		puts   "\tgrpnum:             #{vb.grpnum}"
		puts   "\trecord:             #{vb.record}"
		puts   "\tnrecords:           #{vb.nrecords}"
		puts   "\tupdate_status:      #{vb.update_status}"
		printf("\trec_type:           0x%x\t%s\n", vb.rec_type & 0xff, VBLK_TYPES[vb.rec_type & 0xff])
		puts   "\tdata_length:        #{vb.data_length}"
		puts	"\tpadding.length:    #{vb.padding.length}"
	end
	
	def self.dumpVblk(vb, indent="")
		return if vb.data_length == 0
		puts
		puts "#{indent}VBLK: #{VBLK_TYPES[vb.rec_type]}"
		vb.marshal_dump.each { |k, v| printf("#{indent}\t%-15s: #{v}\n", k) unless (v.kind_of?(Array) || v.kind_of?(OpenStruct)) }
	end

end # module LdmScanner

class LdmMdParser
	
	attr_reader :vgName
	
	def initialize(privhead, pvHdrs)
		@pvHdrs		= pvHdrs        # PV headers hashed by UUID
		@privhead	= privhead
		@vgName		= privhead.diskgroup_name
	end
	
	def parse
		getVgObj
	end
	
	private
	
	def getVgObj
		vgObj = VolumeGroup.new(@privhead.diskgroup_id, @vgName, 1)
		vgObj.lvmType = "LDM"
		
		@pvHdrs.each_value do |pvh|
			next if pvh.diskgroup_name != @vgName
			vgObj.physicalVolumes[pvh.diskVb.name] = getPvObj(vgObj, pvh) if pvh.diskVb
		end
		@privhead.volumes.each do |v|
			vgObj.logicalVolumes[v.name] = getLvObj(vgObj, v)
		end
		return(vgObj)
	end
	
	def getPvObj(vgObj, pvh)
		pvObj = PhysicalVolume.new(pvh.disk_id, pvh.diskVb.name, nil, pvh.logical_disk_size, pvh.logical_disk_start, pvh.logical_disk_size)
		pvObj.vgObj = vgObj
		pvObj.diskObj = pvh.diskObj
		pvObj.diskObj.pvObj = pvObj
		return(pvObj)
	end
	
	def getLvObj(vgObj, vol)
		comp = vol.children.first
		lvObj = LogicalVolume.new(vol.volume_id, vol.name, comp.num_children)
		lvObj.vgObj = vgObj
		lvObj.driveHint = vol.drive_hint
		comp.children.each { |part| lvObj.segments << getSegObj(part) }
		lvObj.segments.sort! { |x, y| x.startExtent <=> y.startExtent }
		return(lvObj)
	end
	
	def getSegObj(part)
		segObj = LvSegment.new(part.volume_offset, part.size, nil, 1)
		segObj.stripes << part.disk.name
		segObj.stripes << part.start
		return(segObj)
	end
	
end # class LdmMdParser

if __FILE__ == $0
	SD = File.dirname(__FILE__)
	$: << File.join(SD, "../disk")
	
	require 'rubygems'
	require 'log4r'
	require 'ostruct'
	require 'MiqDisk'

	#
	# Formatter to output log messages to the console.
	#
	class ConsoleFormatter < Log4r::Formatter
		def format(event)
			(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
		end
	end
	$log = Log4r::Logger.new 'toplog'
	$log.level = Log4r::DEBUG
	Log4r::StderrOutputter.new('err_console', :formatter=>ConsoleFormatter)
	$log.add 'err_console'
	
	# DISK = "/Volumes/WDpassport/Virtual Machines/cn071vcce130/cn071vcce130_3.vmdk"
	# DISK = "/Volumes/WDpassport/Virtual Machines/cn071vcce130/cn071vcce130.vmdk"
	DISK = "/Volumes/WDpassport/Virtual Machines/MIQAppliance-win2008x86/Win2008x86.vmdk"
	puts "VMDB size = #{BinaryStruct.sizeof(LdmScanner::VBLK)}"
	
	diskInfo = OpenStruct.new
	diskInfo.fileName = DISK
	
	disk = MiqDisk.getDisk(diskInfo)

	if !disk
	    puts "Failed to open disk"
	    exit(1)
	end
	
	parts = disk.getPartitions

	puts "Disk type: #{disk.diskType}"
	puts "Disk partition type: #{disk.partType}"
	puts "Disk block size: #{disk.blockSize}"
	puts "Disk start LBA: #{disk.lbaStart}"
	puts "Disk end LBA: #{disk.lbaEnd}"
	puts "Disk start byte: #{disk.startByteAddr}"
	puts "Disk end byte: #{disk.endByteAddr}"
	
	# disk.seek(LdmScanner::PRIVHEAD_OFFSET)
	# ph = LdmScanner.readStruct(disk, LdmScanner::PRIVHEAD)
	# if ph.signature != "PRIVHEAD"
	# 	puts "#{DISK} is not an LDM disk"
	# 	exit
	# end
	# LdmScanner.dumpPrivhead(ph)
	# 
	# tblock_offset = (ph.db_start + LdmScanner::TBLOCK_BLOCK) * LdmScanner::LDM_SECTOR_SIZE
	# disk.seek(tblock_offset)
	# tb = LdmScanner.readStruct(disk, LdmScanner::TOCBLOCK)
	# LdmScanner.dumpTocblock(tb)
	# 
	# vmdb_offset = (ph.db_start + tb.bitmap1_start) * LdmScanner::LDM_SECTOR_SIZE
	# disk.seek(vmdb_offset)
	# vmdb = LdmScanner.readStruct(disk, LdmScanner::VMDB)
	# LdmScanner.dumpVmdb(vmdb)
	# 
	# # puts
	# # puts "=============================================="
	# # 
	# (0...vmdb.sequence).each do |i|
	# 	next unless (vblk = LdmScanner.readVBLK(disk))
	# 	LdmScanner.dumpVblk(vblk)
	# end
	# 
	# LdmScanner.vblkHash.each_value do |v|
	# 	LdmScanner.vblkHash[v.parent_id].children << v if v.parent_id
	# 	v.disk = LdmScanner.vblkHash[v.disk_id] if v.disk_id
	# end
	
	puts
	puts "=============================================="
	
	unless (ph = LdmScanner.scan(disk))
		puts "#{disk.dInfo.fileName} is not an LDM disk"
		disk.close
		exit
	end
	
	if ph.volumes.empty?
		puts "#{disk.dInfo.fileName} has no volumes"
		disk.close
		exit
	end
	
	ph.volumes.each do |v|
		LdmScanner.dumpVblk(v)
		v.children.each do |c|
			LdmScanner.dumpVblk(c, "\t")
			c.children.each do |p|
				LdmScanner.dumpVblk(p, "\t\t")
				LdmScanner.dumpVblk(p.disk, "\t\t\t") if p.disk
			end
		end
	end

	disk.close
end
