require 'ostruct'
require 'enumerator'

require 'binary_struct'
require_relative'MiqSqlite3Util'
require_relative'MiqSqlite3Cell'

module MiqSqlite3DB
  class MiqSqlite3Page
  
    # Page Header.
  	HEADER = BinaryStruct.new([              # All integers are in Big-Endian (or Network) Order
                                          #    OFFSET   SIZE     DESCRIPTION
      'C',  'flags',                      #       0       1      Flags. 1: intkey, 2: zerodata, 4: leafdata, 8: leaf
      'n',  'offset2freeblock',           #       1       2      byte offset to the first freeblock
      'n',  'num_cells',                  #       3       2      number of cells on this page
      'n',  'offset2cell',                #       5       2      first byte of the cell content area
      'C',  'num_fragmented_free_bytes',  #       7       1      number of fragmented free bytes
      'N',  'right_child',                #       8       4      Right child (the Ptr(N) value).  Omitted on leaves.
    ])
    
    SIZEOF_HEADER = HEADER.size
  
    #####################################
    ## Class Methods
    #####################################
  
    def self.getPage(db, pagenum)
  		MiqSqlite3Page.new(db.readPage(pagenum),db,pagenum)
  	end
  	
  	def self.intKey?(f)
      f & 0x01 == 0x01
    end

    def self.zeroData?(f)
      f & 0x02 == 0x02
    end

    def self.leafData?(f)
      f & 0x04 == 0x04
    end

    def self.leaf?(f)
      f & 0x08 == 0x08
    end
  	
    #####################################
    ## Instance Methods
    #####################################

    attr_accessor :buf, :leaf, :hasData, :intKey, :maxLocal, :minLocal, :pagenum

		def initialize(buf, db, pagenum)
			raise "Nil buffer" if buf.nil?
			@pagenum    = pagenum
			@db         = db
			@buf        = buf
			@pagesize   = buf.size
      skip        = (pagenum == 1) ? SIZEOF_DBHEADER : 0
			@header     = OpenStruct.new(HEADER.decode(@buf[skip,SIZEOF_HEADER]))
			decodeFlags
			headerSize  = SIZEOF_HEADER - @childPtrSize
			@data       = buf[skip+headerSize..-1]
			@cells = @cellPointers = nil
		end

    def decodeFlags
      @leafData = MiqSqlite3Page.leafData?(@header.flags)
      @zeroData = MiqSqlite3Page.zeroData?(@header.flags)
      @leaf     = MiqSqlite3Page.leaf?(@header.flags)
      @childPtrSize = @leaf ? 4 : 0
      if MiqSqlite3Page.leafData?(@header.flags)
        @intKey   = MiqSqlite3Page.intKey?(@header.flags)
        @maxLocal = @db.maxLeaf
        @minLocal = @db.minLeaf
      else
        @intKey   = false
        @maxLocal = @db.maxLocal
        @minLocal = @db.minLocal
      end
      @hasData = !(@zeroData || (!@leaf && @leafData))
    end
    
    def each_child
      each_cell { |cell|
        yield cell.left_child if cell.left_child
      }
      yield @header.right_child if !@leaf
    end
    
    def each_cell
      initCells if @cells.nil?
      @cells.each { |c| yield c }
    end
    
    def leaves
      each_child { |child| 
        MiqSqlite3Page.getPage(@db,child).leaves { |p| yield p }
      }
      yield self if @leaf
	  end
		
		
		def dump
		  puts "================="
		  puts "Page:                            #{@pagenum}"
#		  puts "Page Size:                       #{@pagesize}"
#		  puts "Data Size:                       #{@data.size}"
#		  puts "Flags (Raw):                     #{@header.flags}"
		  puts "Flags:                           #{flags2str}"
		  puts "Offset to First Freeblock:       #{@header.offset2freeblock}"
		  puts "Offset to Cell Content Area:     #{@header.offset2cell}"
		  puts "Number of Cells:                 #{@header.num_cells}"
		  puts "Number of Fragmented Free Bytes: #{@header.num_fragmented_free_bytes}"
		  puts "Right Child:                     #{@header.right_child}"   if !@leaf
		  puts "Cell Pointers:                   #{cellPointers2String}"
		  
#		  each_cell { |cell| p cell }
#		  each_child { |kid| puts "Child: #{kid}"}
		  
	  end

    def flags2str
      str = ""
      str << "IntKey "   if @intKey
      str << "ZeroData " if @zeroData
      str << "LeafData " if @leafData
      str << "Leaf "     if @leaf
      return str.chomp
    end
    
    def cellPointers2String
      initCellPointers if @cellPointers.nil?
      str = ""
      @cellPointers.each { |p| str << "#{p} " }
      return nil if str == ""
      return str.chomp
    end
    
    def initCellPointers
      @cellPointers = Array.new
			for i in 1..@header.num_cells
        @cellPointers << @data[(i-1)*2,2].unpack('n')[0]
      end
    end
    
    def initCells
      @cells = Array.new
      initCellPointers if @cellPointers.nil?
      @cellPointers.each { |p| @cells << MiqSqlite3Cell.new(self, p) }
    end

  end

end
