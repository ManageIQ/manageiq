############################################################################################
# Berkeley DB is an embedded database system that supports keyed access to data.
# It stores information in one of the following ways.
#
#   B+tree:  
#      Stores keys in sorted order, using a default function that does lexicographical 
#      ordering of keys.
#
#   Hashing:  
#      Stores records in a hash table for fast searches based on strict equality, 
#      using a default that hashes on the key as a bit string. 
#      Extended Linear Hashing modifies the hash function used by the table as new 
#      records are inserted, in order to keep buckets underfull in the steady state.
#
#   Fixed and Variable-Length Records: 
#      Stores fixed- or variable-length records in sequential order. Record numbers 
#      may be immutable, requiring that new records be added only at the end of the 
#      database, or mutable, permitting new records to be inserted between existing 
#      records.
#
############################################################################################
#
#  This API mimics the Hash-Like Interface presented in the ruby-bdb project located at
#  http://moulon.inra.fr/ruby/bdb.html
#
#  Class Methods
#  =============
#
#  open the database
#    open(filename)
#
#  Instance Methods
#  ================
#
#  Iterators
#
#  Iterates over associations.  { |key, value| ... }
###    each
#
#  Iterates over keys.  { |key| ... }
###    each_key
#
#  Iterates over values. { |value| ... }
###    each_value
#
#  Iterates over each duplicate associations for key.  { |key, value| ... }
#    each_dup(key)
#
#  Iterates over each duplicate values for key.  { |value| ... }
#    each_dup_value(key)
#
#  Returns true if the association from the key exists.
#    has_key?(key)
#
#  Returns true if the association to the value exists.
#    has_value?(value)
#
#  Returns true if the association from key is value
#    has_both?(key, value)
#
#  Return database statistics.
#    stat
#
#  Return the name of the file
#    filename
#
#  Returns the array of the keys in the database
###    keys
#
#  Returns the array of the values in the database.
###    values
#
#  Return an array of all duplicate associations for key
#    duplicates(key)
#
#  Return an array of all associations [key, value]
#    to_a
#
#  Return an hash of all associations {key => value}
#    to_hash
#
#  Returns the value corresponding the key
#    self[key]
#    get(key)
#
#  Returns the number of association in the database
###    size
#
#
############################################################################################




require 'enumerator'

require 'binary_struct'
require 'util/miq-hash_struct'

require_relative 'MiqBdbHash'
require_relative 'MiqBdbBtree'


module MiqBerkeleyDB
	
	# BerkeleyDB constants.
	DBMETASIZE     = 512        # Size of metadata (in bytes) on disk.
	DB_HASHMAGIC   = 0x00061561 # Magic for Hash   database
	DB_BTREEMAGIC  = 0x00053162 # Magic for BTree  database
	DB_QAMMAGIC    = 0x00042253 # Magic for Queue  database
	DB_LOGMAGIC    = 0x00040988 # Magic for Log    database
	DB_RENAMEMAGIC = 0x00030800 # Magic for Rename database
	
	# Database header.
	DBHEADER = BinaryStruct.new([
		'Q',   'lsn',          # 00-07: LSN.
		'L',   'pgno',         # 08-11: Current page number.
		'L',   'magic',        # 12-15: Magic number.
		'L',   'version',      # 16-19: Version.
		'L',   'pagesize',     # 20-23: Pagesize.
		'C',   'encrypt_alg',  # 24: Encryption algorithm.
		'C',   'p_type',       # 25: Page type.
		'C',   'metaflags', 	 # 26: Meta-only flags.
		'C',   'unused1',      # 27: Unused.
		'L',   'free',         # 28-31: Free list page number.
		'L',   'last_pgno',    # 32-35: Page number of last page in db.
		'L',   'unused3',      # 36-39: Unused.
		'L',   'key_count',    # 40-43: Cached key count.
		'L',   'record_count', # 44-47: Cached record count.
		'L',   'flags',        # 48-51: Flags: unique to each AM.
		'a20', 'uid',          # 52-71: Unique file ID.
	])
	
	SIZEOF_DBHEADER = DBHEADER.size
	
	class MiqBdb
		
		attr_reader :db, :header
		
		def initialize(fileName = nil, fs = nil)
			@fs = fs if not fs.nil?
			open(fileName) if not fileName.nil?
		end
		
		# Open the database
		def open(filename)
			# Get header & check.
			@filename = filename
			@file = fileOpen(@filename)
			@header = DBHEADER.decode(@file.read(SIZEOF_DBHEADER))

      # Holds the page buf if we read all pages
      @read_buf = nil
      
			# Check header version - simple warning if less than 8.
			if @header["version"] < 8
				msg = "MiqBerkeleyDB: Database header version is less than 8."
				if $log
					$log.warn(msg)
				else
					puts "WARNING: " + msg
				end
			end
			
			# We don't support encryption.
			raise "MiqBerkeleyDB: This database uses encryption." if @header["encrypt_alg"] != 0
			
			# Open db type (only hash for now, may expand to plugins in the future).
			@db = case @header["magic"]
		        when DB_HASHMAGIC then   MiqBdbHashDatabase.new(self)
		        when DB_BTREEMAGIC then  MiqBdbBtreeDatabase.new(self)
	          when DB_QAMMAGIC then    raise "MiqBerkeleyDB: Database type is Queue"
	          when DB_LOGMAGIC then    raise "MiqBerkeleyDB: Database type is Log"
	          when DB_RENAMEMAGIC then raise "MiqBerkeleyDB: Database type is Rename"
			      else                     raise "MiqBerkeleyDB: Database type #{@header['magic']} is not supported"
		        end
		end
		
		# Close the database
		def close
			@db.close
			@file.close
			@db = @header = @file = @filename = nil
		end
		
		def read(len)
		  raise "File not open" if @file.nil?
		  @file.read(len)
	  end
		
		def nbuckets
		  @db.header.max_bucket + 1
	  end
	  
    def nkeys
      @header["key_count"]
    end
    
    def nrecs
      @header["record_count"]
    end

    def npages
      @header["last_pgno"] + 1
    end

    def pagesize
      @header["pagesize"]
    end
    
    def pages
      @db.pages { |page| yield page }
    end
    
    def readPage(pagenum, buf = @read_buf)
			where = (pagenum * pagesize)
      page = if buf.nil?
        @file.seek(where)
        @file.read(pagesize)
      else
        buf[where, pagesize]
      end
      return page
		end

    def readAllPages
      @file.seek(0)
      @read_buf = @file.read(pagesize * npages)
    end

		def dump
    	out = "File Header\n"
    	out << "  lsn:             #{@header['lsn']}\n"
    	out << "  pgno:            #{@header['pgno']}\n"
    	out << "  magic:           0x#{'%08x' % @header['magic']}\n"
    	out << "  version:         #{@header['version']}\n"
    	out << "  pagesize:        #{@header['pagesize']}\n"
    	out << "  encrypt_alg:     #{@header['encrypt_alg']}\n"
    	out << "  page type:       #{MiqBdbPage.type2string(@header['p_type'])}\n"
    	out << "  metaflags:       0x#{'%08x' % @header['metaflags']}\n"
    	out << "  free:            #{@header['free']}\n"
    	out << "  last_pgno:       #{@header['last_pgno']}\n"
    	out << "  key_count:       #{@header['key_count']}\n"
    	out << "  record_count:    #{@header['record_count']}\n"
    	out << "  flags:           0x#{'%08x' % @header['flags']}\n"
    	out << "  uid:             #{uid_format}\n"
      out << "\n"
    	return out
    end
    
    def keys
      keys = Array.new
      each_key { |k| keys << k }
      return keys
    end
    
    def values
      values = Array.new
      each_value { |v| values << v }
      return values
    end

    def size
      size = 0
      each_key { |k| size += 1 }
      return size
    end
    
    def each
      @db.pages { |page|
  			page.pairs { |k,v|
  			  yield k,v
  	    }
      }
    end
    
    def each_key
      @db.pages { |page|
  			page.keys { |k|
  			  yield k
  	    }
      }
    end
    
    def each_value
      @db.pages { |page|
  			page.values { |v|
  			  yield v
  	    }
      }
    end
		
		private
		
		def fileSize
		  return File.size(@filename) if @fs.nil?
		  return @fs.fileSize(@filename)
	  end
		
		def fileOpen(fileName)
			# Return a file object using MiqFS or File as the case may be.
			if @fs.nil?
				File.open(fileName, "rb")
			else
				@fs.fileOpen(fileName, "r")
			end
		end
		
		def uid_format
			out = ""
			@header['uid'].each_byte do |b| out += sprintf("%02x ", b) end
			return out
		end
		
	end
end
