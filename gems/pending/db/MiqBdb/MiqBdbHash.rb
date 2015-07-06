require 'binary_struct'
require 'util/miq-hash_struct'

require_relative 'MiqBdbPage'

module MiqBerkeleyDB
	
	class MiqBdbHashDatabase
	
  	# Hash constants.
  	DB_HASH_DUP     = 0x01 # Duplicates.
  	DB_HASH_SUBDB   = 0x02 # Subdatabases.
  	DB_HASH_DUPSORT = 0x04 # Duplicates are sorted.
	
  	HASH_HEADER = BinaryStruct.new([
  		'L',    'max_bucket',   # 72-75: ID of Maximum bucket in use.
  		'L',    'high_mask',    # 76-79: Modulo mask into table.
  		'L',    'low_mask',     # 80-83: Modulo mask into table lower half.
  		'L',    'ffactor',      # 84-87: Fill factor.
  		'L',    'nelem',        # 88-91: Number of keys in hash table.
  		'L',    'h_charkey',    # 92-95: Value of hash(CHARKEY).
  		'a128', 'spares',       # 96-223: Spare pages for overflow.
  		'a236', 'unused',       # 224-459: Unused space.
  		'L',    'crypto_magic', # 460-463: Crypto magic number.
  		'a12',  'trash',        # 464-475: Trash space - Do not use.
  		'a16',  'iv',           # 476-495: Crypto IV.
  		'a20',  'chksum',       # 496-511: Page chksum.
  		# NOTE: There is a discrepency between the last two members.
  		# Offset notes show these as 20 and 16 bytes, when they are
  		# in fact 16 and 20 bytes respectively.
  	])
  	
  	SIZEOF_HASH_HEADER = HASH_HEADER.size

  	# Each index references a group of bytes on the page.
    H_KEYDATA	  = 1	  # Key/data item.
    H_DUPLICATE	= 2	  # Duplicate key/data item.
    H_OFFPAGE	  = 3	  # Overflow key/data item.
    H_OFFDUP	  = 4	  # Overflow page of duplicates.
  
    OFFSET_LEN  = 2
  
		attr_reader   :bdb, :header
		
		def initialize(bdb)
			# Read pointer is positioned to hash header.
			@bdb = bdb
			@header = HASH_HEADER.decode(@bdb.read(SIZEOF_HASH_HEADER))
			@header['spares'] = @header['spares'].unpack('L*')
		end
		
		def close
		  @bdb = @header = nil
	  end
	  
    def npages
      @bdb.npages
    end
    
    def nkeys
      @header['nelem']
    end

	  def pages
      0.upto(@header['max_bucket']) do |b|
        pagenum = bucket2page(b)
        while page = MiqBdbPage.getPage(self, pagenum) do
          yield page

          pagenum = page.next
        end
      end
    end

	  def keys(page)
      i = 0
   		while i < page.nentries
   		  key  = entryData(i,   page)

   		  yield key
     	  i += 2  # skip value
   	  end
   	end

 	  def values(page)
      i = 0
   		while i < page.nentries
   		  value = entryData(i+1, page)

   		  yield value
     	  i += 2  # skip key
   	  end
   	end

	  def pairs(page)
      i = 0
   		while i < page.nentries
   		  key  = entryData(i,   page)
   		  value = entryData(i+1, page)
   		  
   		  yield key,value
        i += 2
   	  end
   	end

		def dump
    	out  = ""
    	out << "Hash Database Header\n"
    	out << "  nkeys:           #{@header['nelem']}\n"
    	out << "  high_mask:       0x#{'%01x' % @header['high_mask']}\n"
    	out << "  low_mask:        0x#{'%01x' % @header['low_mask']}\n"
    	out << "  ffactor:         #{@header['ffactor']}\n"
    	out << "  h_charkey:       0x#{'%08x' % @header['h_charkey']}\n"

    	out << "  spare points:    "
      @header['spares'].each { |s| out << s.to_s << " " }
      out << "\n"
      
    	out << "\n"
    	return out
    end

    private

		#
    # The spares table indicates the page number at which each doubling begins.
    # From this page number we subtract the number of buckets already allocated
    # so that we can do a simple addition to calculate the page number here.
    #

    def bucket2page(bucket)
    	bucket + @header['spares'][MiqBdbHashDatabase.log2(bucket + 1)]
  	end
  	
  	def self.log2(num)
    	limit = 1
    	i = 0
    	while limit < num do
    	  limit <<= 1
    	  i      += 1
  	  end
  	  
    	return i
    end
    
    def entryDataOverflow(index, offset, page)
      pgno = page.buf[offset + 4, 4].unpack("S1")[0]
      # Not using the following at the moment
      #tlen = page.buf[offset + 8, 4].unpack("S1")[0]

      data = ""
      while pgno != 0
        opage = MiqBdbPage.getPage(self, pgno)
        data << opage.data[0, opage.offset]
        pgno  = opage.next
      end
      return data
    end

	  def entryDataImmediate(index, offset, page)
	    len  = entryLen(index, offset, page)
	    data = page.buf[offset + 1, len].unpack("A#{len-1}")[0]
	    return data
    end
    
    def entryData(index, page)
      #$log.debug "Getting index #{index} (#{index + 1} / #{page.nentries}) for page #{page.current} (#{page.current + 1} / #{npages})"

      type, offset = entryTypeAndOffset(index, page)
 		  data = case type
 		    when H_KEYDATA then   entryDataImmediate(index, offset, page)
	      when H_OFFPAGE then   entryDataOverflow(index, offset, page)
        when H_DUPLICATE then raise "Unsupported Type: H_DUPLICATE"
        when H_OFFDUP then    raise "Unsupported Type: H_OFFDUP"
        else    		          raise "Unknown Type: #{type.inspect}"
      end

      return data
    end

    def entryTypeAndOffset(index, page)
      offset = entryOffset(index,page)
      type = entryType(offset, page)
      return type, offset
    end

	  def entryType(offset, page)
	    page.buf[offset, 1].ord
    end

    def entryOffset(index, page)
      i = index * OFFSET_LEN
      page.data[i, 2].unpack('S')[0]
    end
    
    def entryLen(index, offset, page)
      item_end = index == 0 ? page.pagesize : entryOffset(index - 1, page)
      return (item_end - offset)
    end

	end

end
