$:.push("#{File.dirname(__FILE__)}/../../../util")

# Utilities.
require 'binary_struct'

# Attribute types & names.
require 'NtfsAttribType'

# Classes.

# An attribute header preceeds each attribute.
require 'NtfsAttribHeader'

# A data run is storage for non-resident attributes.
require 'NtfsDataRun'

# These are the attribute types (so far these are the only types processed).
require 'NtfsAttribAttributeList'
require 'NtfsAttribBitmap'
require 'NtfsAttribStandardInformation'
require 'NtfsAttribFileName'
require 'NtfsAttribObjectId'
require 'NtfsAttribVolumeName'
require 'NtfsAttribVolumeInformation'
require 'NtfsAttribData'
require 'NtfsAttribIndexRoot'
require 'NtfsAttribIndexAllocation'

module NTFS

  # 
  # MFT_RECORD - An MFT record layout
  # 
  # The mft record header present at the beginning of every record in the mft.
  # This is followed by a sequence of variable length attribute records which
  # is terminated by an attribute of type AT_END which is a truncated attribute
  # in that it only consists of the attribute type code AT_END and none of the
  # other members of the attribute structure are present.
  # 


	# One MFT file record, also called MFT Entry.
	FILE_RECORD = BinaryStruct.new([
		'a4', 'signature',                # Always 'FILE'
		'S',  'usa_offset',               # Offset to the Update Sequence Array (usa) from the start of the ntfs record.
		'S',  'usa_count',                # Number of u16 sized entries in the usa including the Update Sequence Number (usn), 
		                                  # thus the number of fixups is the usa_count minus 1.
		'Q',  'lsn',                      # $LogFile sequence number for this record.
                                      # Changed every time the record is modified
		'S',  'seq_num',                  # Number of times this MFT record has been reused
		'S',  'hard_link_count',          # Number of links to this file
		'S',  'offset_to_attrib',         # Byte offset to the first attribute in this mft record from the start of the mft record. 
    				                          # NOTE: Must be aligned to 8-byte boundary.
		'S',  'flags',                    # File record flags
		'L',  'bytes_in_use',             # Number of bytes used in this mft record. 
    				                          # NOTE: Must be aligned to 8-byte boundary.
		'L',  'bytes_allocated',          # Number of bytes allocated for this mft record. This should be equal
		                                  # to the mft record size
		'Q',  'base_mft_record',          # This is zero for base mft records. When it is not zero it is a mft reference 
		                                  # pointing to the base mft record to which this record belongs (this is then 
		                                  # used to locate the attribute list attribute present in the base record which 
		                                  # describes this extension record and hence might need modification when the 
		                                  # extension record itself is modified, also locating the attribute list also 
		                                  # means finding the other potential extents, belonging to the non-base mft record).
		'S',  'next_attrib_id',           # The instance number that will be assigned to the next attribute added to this
                                      # mft record. 
                                      # NOTE: Incremented each time after it is used. 
                                      # NOTE: Every time the mft record is reused this number is set to zero.
                                      # NOTE: The first instance number is always 0

    #
		# The 2 fields below are specific to NTFS 3.1+ (Windows XP and above):
		#
		'S',  'unused1',                  # Reserved/alignment
		'L',  'mft_rec_num',              # Number of this mft record. 
		
		# When (re)using the mft record, we place the update sequence array at this
    # offset, i.e. before we start with the attributes. This also makes sense,
    # otherwise we could run into problems with the update sequence array
    # containing in itself the last two bytes of a sector which would mean that
    # multi sector transfer protection wouldn't work. As you can't protect data
    # by overwriting it since you then can't get it back...
    # When reading we obviously use the data from the ntfs record header.
    # 
		'S',  'fixup_seq_num',            # Magic word at end of sector
	])
	# Here follows the fixup array (WORD).
	SIZEOF_FILE_RECORD = FILE_RECORD.size

	# MftEntry represents one single MFT entry.
	class MftEntry
	  DEBUG_TRACE_MFT = false && $log

		attr_reader :sequenceNum, :recNum, :boot_sector, :mft_entry, :attribs

		MFT_RECORD_IN_USE        = 0x0001  # Not set if file has been deleted
		MFT_RECORD_IS_DIRECTORY  = 0x0002  # Set if record describes a directory
		MFT_RECORD_IS_4          = 0x0004  # MFT_RECORD_IS_4 exists on all $Extend sub-files.  It seems that it marks it is a metadata file with MFT record >24, however, it is unknown if it is limited to metadata files only.
		MFT_RECORD_IS_VIEW_INDEX = 0x0008  # MFT_RECORD_IS_VIEW_INDEX exists on every metafile with a non directory index, that means an INDEX_ROOT and an INDEX_ALLOCATION with a name other than "$I30". It is unknown if it is limited to metadata files only.

		EXPECTED_SIGNATURE       = 'FILE'

		def initialize(bs, recordNumber)
		  log_prefix = "MIQ(NTFS::MftEntry.initialize)"
			raise "#{log_prefix} Nil boot sector" if bs.nil?

      @attribs         = Array.new
      @attribs_by_type = Hash.new { |h, k| h[k] = Array.new }

			# Buffer boot sector & seek to requested record.
			@boot_sector = bs
			bs.stream.seek(bs.mftRecToBytePos(recordNumber))

			# Get & decode the FILE_RECORD.
			@buf       = bs.stream.read(bs.bytesPerFileRec)
			@mft_entry = FILE_RECORD.decode(@buf)

			# Adjust for older versions (don't have unused1 and mft_rec_num).
			version = bs.version
			if version != nil && version < 4.0
				@mft_entry['fixup_seq_num'] = @mft_entry['unused1']
				@mft_entry['mft_rec_num']   = recordNumber
			end

			# Set accessor data.
			@sequenceNum = @mft_entry['seq_num']
			@recNum      = @mft_entry['mft_rec_num']
			@flags       = @mft_entry['flags']

      begin
        # Check for proper signature.
        NtUtil.validate_signature(@mft_entry['signature'], EXPECTED_SIGNATURE)
        # Process per-sector "fixups" that NTFS uses to detect corruption of multi-sector data structures
        @buf = NtUtil.process_fixups(@buf, @boot_sector.bytesPerSector, @mft_entry['usa_offset'], @mft_entry['usa_count'])
      rescue => err
        emsg = "#{log_prefix} Invalid MFT Entry <#{recordNumber}> because: <#{err.message}>"
        $log.error("#{emsg}\n#{dump}")
        raise emsg
      end

			@buf = @buf[@mft_entry['offset_to_attrib']..-1]

      loadAttributeHeaders
		end

		# For string rep, if valid return record number.
		def to_s
			@mft_entry['mft_rec_num'].to_s
		end

		def isDeleted?
		  !NtUtil.gotBit?(@flags, MFT_RECORD_IN_USE)
		end

		def isDir?
		  NtUtil.gotBit?(@flags, MFT_RECORD_IS_DIRECTORY)
		end

		def indexRoot
      if @indexRoot.nil?
        @indexRoot             = getFirstAttribute(AT_INDEX_ROOT)
        @indexRoot.bitmap      = getFirstAttribute(AT_BITMAP)      unless @indexRoot.nil?
        @indexRoot.allocations = getAttributes(AT_INDEX_ALLOCATION) unless @indexRoot.nil?
      end

      @indexRoot
	  end

    def attributeData
      if @attributeData.nil?
        dataArray = getAttributes(AT_DATA)

        unless dataArray.nil?
          dataArray.compact!
          if dataArray.size > 0
            @attributeData = dataArray.shift
            dataArray.each { |datum| @attributeData.data.addRun(datum.run) }
          end
        end
      end

      @attributeData
    end

	  def rootAttributeData
	    loadFirstAttribute(AT_DATA)
    end

	  def attributeList
      @attributeList ||= loadFirstAttribute(AT_ATTRIBUTE_LIST)
    end

		def loadAttributeHeaders
      offset = 0
			while h = AttribHeader.new(@buf[offset..-1])
				break if h.type.nil? || h.type == AT_END
        $log.debug "NtfsMftEntry.loadAttributeHeaders - MFT(#{@recNum}) adding  Attr: #{h.typeName}" if DEBUG_TRACE_MFT
        attrib = { "type" => h.type, "offset" => offset, "header" => h }
        @attribs                 << attrib
        @attribs_by_type[h.type] << attrib
				offset += h.length
			end
      @attribs_by_type.each { |k, v| $log.debug "NtfsMftEntry.loadAttributeHeaders - MFT(#{@recNum}) Attr: #{TypeName[k]} => Count: #{v.size}" }  if DEBUG_TRACE_MFT
    end

		def getFirstAttribute(attribType)
		  getAttributes(attribType).first
	  end

		def getAttributes(attribType)
      $log.debug "NtfsMftEntry.getAttributes        - MFT(#{@recNum}) getting Attr: #{TypeName[attribType]}" if DEBUG_TRACE_MFT
      attributeList.nil? ? loadAttributes(attribType) : attributeList.loadAttributes(attribType)
	  end

		def loadFirstAttribute(attribType)
		  loadAttributes(attribType).first
	  end

  	def loadAttributes(attribType)
  	  result  = []
  	  if @attribs_by_type.has_key?(attribType)
        $log.debug "NtfsMftEntry.loadAttributes       - MFT(#{@recNum}) loading Attr: #{TypeName[attribType]}" if DEBUG_TRACE_MFT

        @attribs_by_type[attribType].each { |attrib|
          attrib["attr"] = createAttribute(attrib["offset"], attrib["header"]) unless attrib.has_key?('attr')
          result << attrib["attr"]
        }
      end
      result
		end

		def createAttribute(offset, header)
      $log.debug "NtfsMftEntry.createAttribute >> type=#{TypeName[header.type]} header=#{header.inspect}" if DEBUG_TRACE_MFT

		  buf = header.get_value(@buf[offset..-1], @boot_sector)

		  return StandardInformation.new(buf)                             if header.type == AT_STANDARD_INFORMATION
      return FileName.new(buf)                                        if header.type == AT_FILE_NAME
	    return ObjectId.new(buf)                                        if header.type == AT_OBJECT_ID
	    return VolumeName.new(buf)                                      if header.type == AT_VOLUME_NAME
	    return VolumeInformation.new(buf)                               if header.type == AT_VOLUME_INFORMATION
	    return AttributeList.new(buf, @boot_sector)                     if header.type == AT_ATTRIBUTE_LIST
      return AttribData.create_from_header(header, buf)               if header.type == AT_DATA
  	  return IndexRoot.create_from_header(header, buf, @boot_sector)  if header.type == AT_INDEX_ROOT
  	  return IndexAllocation.create_from_header(header, buf)          if header.type == AT_INDEX_ALLOCATION
  	  return Bitmap.create_from_header(header, buf)                   if header.type == AT_BITMAP

      # Attribs are unrecognized if they don't appear in TypeName.
      unless TypeName.has_key?(header.type)
        msg = "MIQ(NTFS::MftEntry.createAttribute) Unrecognized attribute type: 0x#{'%08x' % header.type} -- header: #{header.inspect}"
        $log.warn(msg) if $log
        raise(msg)
      end

      return nil
	  end

		def dump
			ref = NtUtil.MkRef(@mft_entry['base_mft_record'])

			out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
			out << "  Signature       : #{@mft_entry['signature']}\n"
			out << "  USA Offset      : #{@mft_entry['usa_offset']}\n"
			out << "  USA Count       : #{@mft_entry['usa_count']}\n"
			out << "  Log file seq num: #{@mft_entry['lsn']}\n"
			out << "  Sequence number : #{@mft_entry['seq_num']}\n"
			out << "  Hard link count : #{@mft_entry['hard_link_count']}\n"
			out << "  Offset to attrib: #{@mft_entry['offset_to_attrib']}\n"
			out << "  Flags           : 0x#{'%04x' % @mft_entry['flags']}\n"
			out << "  Real size of rec: #{@mft_entry['bytes_in_use']}\n"
			out << "  Alloc siz of rec: #{@mft_entry['bytes_allocated']}\n"
			out << "  Ref to base rec : seq #{ref[0]}, entry #{ref[1]}\n"
			out << "  Next attrib id  : #{@mft_entry['next_attrib_id']}\n"
			out << "  Unused1         : #{@mft_entry['unused1']}\n"
			out << "  MFT rec num     : #{@mft_entry['mft_rec_num']}\n"
			out << "  Fixup seq num   : 0x#{'%04x' % @mft_entry['fixup_seq_num']}\n"
			@attribs.each { |hash|
				begin
				  header = hash["header"]
					out   << header.dump

				  attrib = hash["attr"]
					out   << attrib.dump if not attrib.nil?
				rescue NoMethodError
				end
			}

			return out
		end

	end
end # module NTFS
