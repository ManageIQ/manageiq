require 'ReiserFSUtils'

module ReiserFS
	
	class Block
		
		BLOCK_HEADER = BinaryStruct.new([
    	'v',	 'level',					    # Level of the block in the tree
    	'v',   'nitems',            # The number of items in the block
      'x20', nil                  # Ignoring the following, as they are not presently used
                                  #  'v',  'free_space', # Free space left in the block
                                  #  'a2', 'reserved',
                                  #  'a16','right_key',  # right delimiting key for the block
    ])
    SIZEOF_BLOCK_HEADER = BLOCK_HEADER.size
    
    attr_reader :blockNum, :data
    
		def initialize(data, bnum)
		  @blockNum = bnum
		  @data     = data
		  @bh       = BLOCK_HEADER.decode(@data)
		  @nitems   = @bh['nitems']
		  @level    = @bh['level']
      @iHeaders = Hash.new
	  end
		
    def nkeys
      return @nitems
    end
    
    def npointers
      return 0 if isLeaf?
      return @nitems+1
    end
    
    
    KEY = BinaryStruct.new([
      'V',  'directory_id',
      'V',  'object_id',
      'V',  'offset',
      'V',  'type'
    ])
    SIZEOF_KEY = KEY.size
    
    def data2key(keydata)
      key = KEY.decode(keydata)
      key['type'] = Utils.type2integer(key['type'])
      return key
    end
    
    # Keys are 1-based
    def getKey(k)
      return nil if k > @nitems || k <= 0
      pos = SIZEOF_BLOCK_HEADER + (SIZEOF_KEY * (k-1))
      keydata = @data[pos,SIZEOF_KEY] 
      return data2key(keydata)
    end
    
    POINTER = BinaryStruct.new([
      'V',  'block_number',
      'v',  'size',
      'a2', 'reserved',
    ])
    SIZEOF_POINTER = POINTER.size
    
    # Pointers are 0-based
    def getPointer(p)
#puts "getPointer >> p=#{p}"      
      return nil if p > @nitems || p < 0
      pos = SIZEOF_BLOCK_HEADER + (SIZEOF_KEY * @nitems) + (SIZEOF_POINTER * p)
      ptrdata = @data[pos,SIZEOF_POINTER] 
      return POINTER.decode(ptrdata)
    end
    
    def findPointer(searchKey)
#puts "findPointer >> #{dumpKey(searchKey, "searchKey")}"
      (1..@nitems).each { |i|
        currentKey = getKey(i)
        compare = Utils.compareKeys(searchKey, currentKey)
#puts dumpKey(currentKey, "currentKey(#{i})")
        next                   if compare  > 0
        return getPointer(i-1) if compare <= 0
      }
      return getPointer(@nitems)
    end
    
    def findPointers(searchKey)
      pointers = Array.new
      compare  = nil

      (1..@nitems).each { |i|
        currentKey = getKey(i)
        compare = Utils.compareKeys(searchKey, currentKey)
#puts dumpKey(currentKey, "currentKey(#{i})")
        next  if compare > 0
        pointers << getPointer(i-1)
        break if compare < 0
      }
      pointers << getPointer(@nitems) if pointers.size == 0 || compare == 0
      
      return pointers
    end
    
    ITEM_HEADER = BinaryStruct.new([
      'a16',  'key',
      'v',    'count',
      'v',    'length',
      'v',    'location',
      'v',    'version'
    ])
    SIZEOF_ITEM_HEADER = ITEM_HEADER.size
        
    def getItemHeaders(key=nil)
      return @iHeadersAll if key.nil? && !@iHeadersAll.nil?

      did = Utils.getKeyDirectoryID(key) if key
      oid = Utils.getKeyObjectID(key)    if key

      iHeaders = Array.new
      (1..nkeys).each { |i|
        iheader = getItemHeader(i)
        if key
          curKey = iheader['key']
          next if did != Utils.getKeyDirectoryID(curKey)
          next if oid != Utils.getKeyObjectID(curKey)
        end

        iHeaders << iheader
      }

      @iHeadersAll = iHeaders if key.nil?

      return iHeaders
    end


    def getItemHeader(i)
      return @iHeaders[i] if @iHeaders.has_key?(i)
      return nil if i > @nitems || i <= 0

      pos = SIZEOF_BLOCK_HEADER + (SIZEOF_ITEM_HEADER * (i-1))
      iheaddata = @data[pos,SIZEOF_ITEM_HEADER]
      keydata   = iheaddata[0,SIZEOF_KEY]
      key       = data2key(keydata)
      iheader   = ITEM_HEADER.decode(iheaddata)
      iheader['key'] = key
      return @iHeaders[i] = iheader
    end
    
    def getItemVersion(iheader)
      return iheader['version']
    end
    
    def getItemCount(iheader)
      return iheader['count']
    end
    
    def getItemType(iheader)
      return iheader['key']['type']
    end
    
    def getItem(iheader)
      offset = iheader['location']
      length = iheader['length']
      return @data[offset,length]
    end
    
    def isLeaf?
      @level == 1
    end
    

		def dump
		  out = dumpHeader
		  
		  if isLeaf?
		    (1..@nitems).each { |i|
          ihead = getItemHeader(i)
          out  += dumpItemHeader(ihead, "Item Header #{i}")
        }
	    else
        (1..@nitems).each { |i|
          key  = getKey(i)
          out += dumpKey(key, "Key #{i}")
        }
        out += "\n"
        (0..@nitems).each { |i|
          ptr  = getPointer(i)
          out += dumpPointer(ptr, "Ptr #{i}")
        }
      end
		  return out
	  end
	  
	  def dumpHeader
		  return "Block Header: blockNum=#{@blockNum} nitems=#{@bh['nitems']} level=#{@bh['level']}\n"
    end
	  
	  def dumpKey(key, label = nil)
      return "#{Utils.dumpKey(key,label)}\n"
    end
    
    def dumpPointer(ptr, label = nil)
      return "#{label}:\t\{#{ptr['block_number']},#{ptr['size']}\}\n"
    end
    
	  def dumpItemHeader(ihead, label = nil)
	    key = ihead['key']
      keystring = "\{#{key['directory_id']},#{key['object_id']},#{key['offset']},#{key['type']}\}"
      return "#{label}:\t\{#{keystring},#{ihead['count']},#{ihead['length']},#{ihead['location']},#{ihead['version']}\}\n"
    end
		
	end

end



