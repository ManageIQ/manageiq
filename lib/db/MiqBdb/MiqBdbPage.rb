require 'enumerator'

require 'binary_struct'
require 'util/miq-hash_struct'
require 'util/extensions/miq-string'

module MiqBerkeleyDB

	class MiqBdbPage
		
  	# Page numbers.
   	PGNO_INVALID = 0
  	PGNO_BASE_MD = 0

  	# Page types
    P_INVALID	      = 0	  # Invalid page type
    P_DUPLICATE	    = 1	  # Duplicate. DEPRECATED in 3.1
    P_HASH		      = 2	  # Hash
    P_IBTREE	      = 3	  # Btree internal
    P_IRECNO	      = 4	  # Recno internal
    P_LBTREE	      = 5	  # Btree leaf
    P_LRECNO	      = 6	  # Recno leaf
    P_OVERFLOW	    = 7	  # Overflow
    P_HASHMETA	    = 8	  # Hash metadata page
    P_BTREEMETA	    = 9	  # Btree metadata page
    P_QAMMETA	      = 10	# Queue metadata page
    P_QAMDATA	      = 11	# Queue data page
    P_LDUP		      = 12	# Off-page duplicate leaf
    
    def self.type2string(t)
			return case t
				when P_INVALID then   "invalid"
			  when P_DUPLICATE then "duplicate (deprecated)"
				when P_HASH then      "hash"
			  when P_IBTREE then    "btree internal"
			  when P_IRECNO then    "recno internal"
		    when P_LBTREE then    "btree leaf"
		    when P_LRECNO then    "recno leaf"
				when P_OVERFLOW then  "overflow"
				when P_HASHMETA then  "hash metadata"
				when P_BTREEMETA then "btree metadata"
				when P_QAMMETA then   "queue metadata"
				when P_QAMDATA then   "queue data"
			  when P_LDUP then      "offpage duplicate leaf"
		    else                  "unknown value of #{t}"
			end
		end
		
		# Page Header.
		HEADER = BinaryStruct.new([
			                        # 00-07: Log sequence number (LSN)
			'L', 'lsn_file',        #   0-3: LSN File
			'L', 'lsn_offset',      #   4-7: LSN Offset
			'L', 'pgno',            # 08-11: Current page number
			'L', 'prev_pgno',       # 12-15: Previous page number
			'L', 'next_pgno',       # 16-19: Next page number
			'S', 'entries',         # 20-21: Number of items on the page
			'S', 'hf_offset',       # 22-23: High free byte page offset
			'C', 'level',           #    24: Btree tree level
			'C', 'p_type'           #    25: Page type
		])
		
		SIZEOF_HEADER = HEADER.size
		
		#
    # With many compilers sizeof(PAGE) == 28, while SIZEOF_PAGE == 26.
    # We add in other things directly after the page header and need
    # the SIZEOF_PAGE.  When giving the sizeof(), many compilers will
    # pad it out to the next 4-byte boundary.
    #
    SIZEOF_PAGE	= 26
    
		attr_reader :header, :data, :pagesize, :buf

    def self.getPage(db, pagenum)
	    return nil if pagenum == PGNO_INVALID
#			return nil if pagenum >= db.npages

			buf = db.bdb.readPage(pagenum)
			return nil if buf.nil? || buf[25, 1].ord == P_INVALID
			MiqBdbPage.new(buf,db)
		end
      
		def initialize(buf, db)
			raise "Nil buffer." if buf.nil?
			@db         = db
			@buf        = buf
			@pagesize   = buf.size
			@header     = HEADER.decode(@buf[0, SIZEOF_HEADER])
			@data       = buf[SIZEOF_HEADER..-1]
		end
	

    def current
      @header['pgno']
    end

		def next
		  @header['next_pgno']
	  end
	  
	  def prev
		  @header['prev_pgno']
	  end
	  
	  def nentries
      @header['entries']
    end
    
    def offset
      @header['hf_offset']
    end
    
    def level
      @header['level']
    end
    
    def ptype
      @header['p_type']
    end

    def keys
      @db.keys(self) { |k| yield k }
    end

    def values
      @db.values(self) { |v| yield v }
    end

    def pairs
      @db.pairs(self) { |k, v| yield k,v }
    end
      
  	# Dump page statistics like db_dump.
  	def dump
  	  out  = ""
    	out << "Page #{current}\n"
  		out << "  type:            #{MiqBdbPage.type2string(ptype)}\n"
  		out << "  prev:            #{prev}\n"
  		out << "  next:            #{@header['next_pgno']}\n"
  		out << "  log seq num:     file=#{@header['lsn_file']}  offset=#{@header['lsn_offset']}\n"
  		out << "  level:           #{level}\n"
		
  		if @header['p_type'] == P_OVERFLOW
    		out << "  ref cnt:         #{nentries}\n"
    		out << "  len:             #{offset}\n"
  		else
    		out << "  entries:         #{nentries}\n"
    		out << "  offset:          #{offset}\n"
  		end
		  out << "  data size:       #{@data.size}\n"
  		out << "  data:            "
		
  		@data.bytes.take(20).each do |c|
  			out << sprintf("%.2x ", c)
  		end
  		out << "..." if @data.size > 20

   		out << "\n\n"
  		return out
  	end
	
	end

end


