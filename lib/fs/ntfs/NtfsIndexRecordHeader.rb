require 'NtUtil'

$:.push("#{File.dirname(__FILE__)}/../../../util")
require 'binary_struct'

module NTFS

  # 
  # INDEX_BLOCK - Attribute: Index allocation (0xa0).
  # 
  # NOTE: Always non-resident (doesn't make sense to be resident anyway!).
  # 
  # This is an array of index blocks. Each index block starts with an
  # INDEX_BLOCK structure containing an index header, followed by a sequence of
  # index entries (INDEX_ENTRY structures), as described by the INDEX_HEADER.
  # 

	INDEX_RECORD_HEADER = BinaryStruct.new([
		'a4', 'signature',          # Always 'INDX'
		'S',  'usa_offset',         # Offset to the Update Sequence Array (usa) from the start of the ntfs record.
		'S',  'usa_count',          # Number of u16 sized entries in the usa including the Update Sequence Number (usn), 
		                            # thus the number of fixups is the usa_count minus 1.
		'Q',  'lsn',                # $LogFile sequence number of the last modification of this index block
		'Q',  'index_block_vcn',    # VCN of this record in the full index stream.
	])
	# Here follows the fixup array.
	# Here follows an index node header.
	SIZEOF_INDEX_RECORD_HEADER = INDEX_RECORD_HEADER.size

	class IndexRecordHeader
    EXPECTED_SIGNATURE = 'INDX'

		attr_reader :valid, :signature, :vcn
		attr_accessor :data

	  def self.size
	    SIZEOF_INDEX_RECORD_HEADER
    end

		def initialize(buf, bps)
		  log_prefix = "MIQ(NTFS::IndexRecordHeader.initialize)"
			raise "#{log_prefix} Nil buffer"           if buf.nil?
			raise "#{log_prefix} Nil bytes per sector" if bps.nil?

			buf        = buf.read(buf.length)   if buf.kind_of?(DataRun)
			@data      = buf
			@bps       = bps

			# Decode the index record header structure.
			@irh       = INDEX_RECORD_HEADER.decode(buf)
			@signature = @irh['signature']
			@vcn       = @irh['index_block_vcn']
      @valid     = true

      begin
        # Check for proper signature.
        NtUtil.validate_signature(@irh['signature'], EXPECTED_SIGNATURE)
        # Process per-sector "fixups" that NTFS uses to detect corruption of multi-sector data structures
        @data = NtUtil.process_fixups(@data, @bps, @irh['usa_offset'], @irh['usa_count'])
      rescue => err
        @valid = false
        $log.error("#{log_prefix} Invalid Index Record Header because: <#{err.message}>\n#{dump}")
      end

		end

    def isValid?
      @valid
    end

		def to_s
			@irh['signature']
		end

		def dump(withData = nil)
			out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
			out << "  Signature                : #{@irh['signature']}\n"
			out << "  USA Offset               : #{@irh['usa_offset']}\n"
			out << "  USA Count                : #{@irh['usa_count']}\n"
			out << "  $LogFile sequence number : #{@irh['lsn']}\n"
			out << "  Index Block VCN          : #{@irh['index_block_vcn']}\n"
			if withData
				out << "Raw Data:\n"
				out << @data.hex_dump
			end
			out << "---\n"
		end
	end
end # module NTFS
