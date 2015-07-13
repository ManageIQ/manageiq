require 'NtUtil'

$:.push("#{File.dirname(__FILE__)}/../../../util")
require 'binary_struct'
require 'miq-unicode'

module NTFS
		
  # 
  # ATTR_LIST_ENTRY - Attribute: Attribute list (0x20).
  # 
  # - Can be either resident or non-resident.
  # - Value consists of a sequence of variable length, 8-byte aligned,
  # ATTR_LIST_ENTRY records.
  # - The attribute list attribute contains one entry for each attribute of
  # the file in which the list is located, except for the list attribute
  # itself. The list is sorted: first by attribute type, second by attribute
  # name (if present), third by instance number. The extents of one
  # non-resident attribute (if present) immediately follow after the initial
  # extent. They are ordered by lowest_vcn and have their instance set to zero.
  # It is not allowed to have two attributes with all sorting keys equal.
  # - Further restrictions:
  #  - If not resident, the vcn to lcn mapping array has to fit inside the
  #    base mft record.
  #  - The attribute list attribute value has a maximum size of 256kb. This
  #    is imposed by the Windows cache manager.
  # - Attribute lists are only used when the attributes of mft record do not
  # fit inside the mft record despite all attributes (that can be made
  # non-resident) having been made non-resident. This can happen e.g. when:
  #  - File has a large number of hard links (lots of file name
  #    attributes present).
  #  - The mapping pairs array of some non-resident attribute becomes so
  #    large due to fragmentation that it overflows the mft record.
  #  - The security descriptor is very complex (not applicable to
  #    NTFS 3.0 volumes).
  #  - There are many named streams.
  # 
   
	ATTRIB_ATTRIBUTE_LIST = BinaryStruct.new([
		'L',  'attrib_type',    # Type of referenced attribute
		'S',  'length',					# Byte size of this entry
		'C',	'name_length',    # Size in Unicode chars of the name of the attribute or 0 if unnamed
		'C',	'name_offset',    # Byte offset (from start of entry) to beginning of attribute name 
		'Q',  'first_vcn',      # Lowest virtual cluster number of this portion of the attribute value. 
		                        # This is usually 0. It is non-zero for the case where one attribute
                            # does not fit into one mft record and thus several mft records are 
                            # allocated to hold this attribute. In the latter case, each mft
                            # record holds one extent of the attribute and there is one attribute 
                            # list entry for each extent. 
                            # NOTE: This is DEFINITELY a signed value! The windows driver uses cmp, followed
                            # by jg when comparing this, thus it treats it as signed.
		'Q',  'mft_reference',  # The reference of the mft record holding the ATTR_RECORD for this 
		                        # portion of the attribute value
		'S',  'attrib_id',      # If lowest_vcn = 0, the instance of the attribute being referenced; otherwise 0.
		
	])
	SIZEOF_ATTRIB_ATTRIBUTE_LIST = ATTRIB_ATTRIBUTE_LIST.size

	# One $ATTRIBUTE_LIST attribute.
	class AttributeList
		attr_reader :list

		def initialize(buf, boot_sector)
			@boot_sector = boot_sector
			buf          = buf.read(buf.length) if buf.class.kind_of?(DataRun)
			
			# Start an attribute list.
			pos   = 0
			@list = Array.new

			# Keep it up til we hit an AT_END type
			# OR until no more data - apparently the end of a list is not always marked.
			loop do
				break if pos + SIZEOF_ATTRIB_ATTRIBUTE_LIST > buf.length
				# Decode this attrib specifier.
				aal = ATTRIB_ATTRIBUTE_LIST.decode(buf[pos, SIZEOF_ATTRIB_ATTRIBUTE_LIST])

				break if aal['attrib_type'] == AT_END
				
				# If there's a name get it.
				len = aal['name_length'] * 2
				aal['name'] = buf[pos + aal['name_offset'], len].UnicodeToUtf8 if len > 0
				
				# Log instances of funky references.
				aal['mft'] = NtUtil.MkRef(aal['mft_reference'])[1]
				
				# Store (if not bad)
				@list << aal  if aal['mft'] <= @boot_sector.maxMft

				# advance to next attribute
				pos += aal['length']
			end
			
		end
	  
		def to_s
			super
		end
	  
		# Load attributes of requested type
		def loadAttributes(attribType)
		  result = []
		  
			# ad is an attribute descriptor.
			@list.each do |ad|
				next unless ad['attrib_type'] == attribType
					
				# Load referenced attribute and add it to parent.
				result += @boot_sector.mftEntry(ad['mft']).loadAttributes(attribType)
			end
			
	    result
		end
		
		def dump
			out = "\#<#{self.class}:0x#{'%08x' % self.object_id}>, #{@list.size} attributes:\n"
			@list.each { |at| out << dumpElement(at) }
			return out
		end
		
		def dumpElement(at)
			ref = NtUtil.MkRef(at['mft_reference'])
			out = "\#<#{at.class}:0x#{'%08x' % at.object_id}> (#{TypeName[at['attrib_type']]} - #{at['name'] ? at['name'] : '[unnamed]'})\n"
			out << "Type    : 0x#{'%08x' % at['attrib_type']}\n"
			out << "Length  : 0x#{'%04x' % at['length']}\n"
			out << "NameLen : #{at['name_length']}\n"
			out << "NameOfs : #{at['name_offset']}\n"
			out << "FirstVCN: 0x#{'%016x' % at['first_vcn']}\n"
			out << "BaseRef : #{ref[0]}, #{ref[1]}\n"
			out << "BaseRef : 0x#{'%016x' % ref[1]}\n"
			out << "AttribID: #{at['attrib_id']}\n\n"
			return out
		end
		
	end #class AttributeList
	
end #module NTFS
