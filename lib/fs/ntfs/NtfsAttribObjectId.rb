require 'rubygems'
require 'miq-uuid'

module NTFS

	# There is no real data definition for this class - it consists entirely of GUIDs.
  # 
  # struct GUID - GUID structures store globally unique identifiers (GUID).
  # 
  # A GUID is a 128-bit value consisting of one group of eight hexadecimal
  # digits, followed by three groups of four hexadecimal digits each, followed
  # by one group of twelve hexadecimal digits. GUIDs are Microsoft's
  # implementation of the distributed computing environment (DCE) universally
  # unique identifier (UUID).
  # 
  # Example of a GUID:
  #  1F010768-5A73-BC91-0010-A52216A7227B
  #

	class ObjectId
	  
		attr_reader :objectId, :birthVolumeId, :birthObjectId, :domainId
	  
		def initialize(buf)
			raise "MIQ(NTFS::ObjectId.initialize) Nil buffer" if buf.nil?
	    buf = buf.read(buf.length) if buf.kind_of?(DataRun)
			len = 16
			@objectId       = MiqUUID.parse_raw(buf[len * 0, len])
			@birthVolumeId  = MiqUUID.parse_raw(buf[len * 1, len]) if buf.length > 16
			@birthObjectId  = MiqUUID.parse_raw(buf[len * 2, len]) if buf.length > 16
			@domainId       = MiqUUID.parse_raw(buf[len * 3, len]) if buf.length > 16
		end
	  
		def dump
			out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>\n"
			out << "  Object id      : #{@objectId}\n"
			out << "  Birth volume id: #{@birthVolumeId}\n"
			out << "  Birth object id: #{@birthObjectId}\n"
			out << "  Domain id      : #{@domainId}\n"
			out << "---\n"
		end
	  
	end
end # module NTFS
