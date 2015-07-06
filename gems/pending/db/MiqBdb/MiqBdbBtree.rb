require 'binary_struct'
require 'util/miq-hash_struct'

require_relative 'MiqBdbPage'

module MiqBerkeleyDB

	class MiqBdbBtreeDatabase
	  BTREE_HEADER = BinaryStruct.new([
  		'L',    'unused1',      # 72-75: Unused space.
  		'L',    'minkey',       # 76-79: Btree: Minkey
  		'L',    're_rlen',      # 80-83: Recno: fixed-len record length
  		'L',    're_pad',       # 84-87: Recno: fixed-len record pad
  		'L',    'root',         # 88-91: Root page
  		'a368', 'unused2',      # 92-459: Unused space
  		'L',    'crypto_magic', # 460-463: Crypto magic number.
  		'a12',  'trash',        # 464-475: Trash space - Do not use.
  		'a16',  'iv',           # 476-495: Crypto IV.
  		'a20',  'chksum',       # 496-511: Page chksum.
  	])

  	SIZEOF_BTREE_HEADER = BTREE_HEADER.size

    BINTERNAL_HEADER = BinaryStruct.new([
      'S',    'len',          # 00-01: Key/data item length
      'C',    'ptype',        #    02: Page type (AND DELETE FLAG)
      'C',    'unused',       #    03: Padding, unused
      'L',    'pgno',         # 04-07: Page number of referenced page
      'L',    'nrecs',        # 08-11: Subtree record count
    ])

    SIZEOF_BINTERNAL_HEADER = BINTERNAL_HEADER.size

    #
    # Each index references a group of bytes on the page
    #
    B_KEYDATA	  = 1	# Key/data item
    B_DUPLICATE	= 2	# Duplicate key/data item
    B_OVERFLOW	= 3 # Overflow key/data item

    B_DELETE	  = 0x80

    OFFSET_LEN  = 2

  	#
  	# The btree levels are numbered from the leaf to the root, starting
  	# with 1, so the leaf is level 1, its parent is level 2, and so on.
  	# We maintain this level on all btree pages, but the only place that
  	# we actually need it is on the root page.  It would not be difficult
  	# to hide the byte on the root page once it becomes an internal page,
  	# so we could get this byte back if we needed it for something else.
  	#


		attr_reader   :bdb, :header

		def initialize(bdb)
			# Read pointer is positioned to hash header.
			@bdb = bdb
			@header = BTREE_HEADER.decode(@bdb.read(SIZEOF_BTREE_HEADER))
		end

		def close
		  @bdb = @header = nil
	  end

	  def keys(page)
      leaves(page) do |leaf|
        btree_leaf_keys(leaf) do |k|
          yield k
        end
      end
    end

	  def values(page)
      leaves(page) do |leaf|
        btree_leaf_values(leaf) do |v|
          yield v
        end
      end
    end

	  def pairs(page)
      leaves(page) do |leaf|
        btree_leaf(leaf) do |k,v|
          yield k,v
        end
      end
    end

    def pages
      pagenum = @header['root']
      while page = MiqBdbPage.getPage(self, pagenum) do

        yield page

        pagenum = page.next
      end
    end

		def dump
    	out  = ""
    	out << "B-Tree Database Header\n"
    	out << "  minkey:          #{@header['minkey']}\n"
    	out << "  re_rlen:         #{@header['re_rlen']}\n"
    	out << "  re_pad:          #{@header['re_pad']}\n"
    	out << "  root:            #{@header['root']}\n"
    	out << "\n"
    	return out
    end

    private

		def btreei_dump(h, index=nil)
		  out  = ""
		  out << "B-Tree Internal Node"
		  out << " (#{index})" if index
		  out << "\n"
		  out << "  key/data item length: #{h.len}\n"
		  out << "  page number:          #{h.pgno}\n"
		  out << "  page type:            #{MiqBdbPage.type2string(h.ptype)}\n"
		  out << "  subtree record count: #{h.nrecs}\n"
		  out << "\n"
		  return out
	  end

		def btree_leaf(page)
      i = 0
   		while i < page.nentries
   		  key   = entryData(i,   page)
   		  value = entryData(i+1, page)

   		  yield key,value if key.size > 0
     	  i += 2  # skip value
   	  end
	  end

		def btree_leaf_keys(page)
      i = 0
   		while i < page.nentries
   		  key   = entryData(i,   page)

   		  yield key if key.size > 0
     	  i += 2  # skip value
   	  end
	  end

    def btree_leaf_values(page)
      i = 0
   		while i < page.nentries
   		  key   = entryData(i,   page)
   		  value = entryData(i+1, page)

   		  yield value if key.size > 0
     	  i += 2  # skip value
   	  end
	  end

		def leaves(page)
			for index in 0..page.nentries-1
        header = BINTERNAL_HEADER.decode(page.buf[entryOffset(index,page),(SIZEOF_BINTERNAL_HEADER)])

        btpage = MiqBdbPage.getPage(self, header['pgno'])
        bttype = MiqBdbPage.type2string(btpage.ptype)
        case bttype
          when "btree internal"; leaves(btpage) { |leaf| yield leaf }
          when "btree leaf";     yield btpage
          else                   raise "Unexpected Page Type: #{bttype}"
        end
		  end
	  end

    def entryOffset(index, page)
      i = index*OFFSET_LEN
      page.data[i..i+1].unpack('S')[0]
    end

	  def entryType(index, page)
	    page.buf[entryOffset(index,page)+2,1].unpack('C')[0] & ~B_DELETE
    end

    def entryDataImmediate(index, page)
      # B_KEYDATA
      #	00-01: Key/data item length
      #    02: Page type AND DELETE FLAG
      #        Data Follows
	    len  = page.buf[entryOffset(index,page),2].unpack('S')[0]
	    data = page.buf[entryOffset(index,page)+3,len].unpack("A#{len}")[0]
    end

    def entryDataOverflow(index, page)
      # B_DUPLICATE and B_OVERFLOW
      # 00-01: Padding, unused
    	#    02: Page type AND DELETE FLAG
    	#    03: Padding, unused
    	# 04-07: Next page number
    	# 08-11: Total length of item
    	pgno = page.buf[entryOffset(index,page)+4,4].unpack("S1")[0]
      # Not using the following at the moment
      #tlen = page.buf[entryOffset(index,page)+8,4].unpack("S1")[0]

      data = ""
      while pgno != 0
        opage = MiqBdbPage.getPage(self, pgno)
        data << opage.data[0,opage.offset]
        pgno  = opage.next
      end
      return data
    end

    def entryData(index, page)
      type = entryType(index, page)
 		  case type
 		    when B_KEYDATA;   return entryDataImmediate(index, page)
	      when B_OVERFLOW;  return entryDataOverflow(index, page)
        when B_DUPLICATE; raise "Unsupported Type: B_DUPLICATE"
        else    		      raise "Unknown Type: #{type}"
      end
    end

  end
end
