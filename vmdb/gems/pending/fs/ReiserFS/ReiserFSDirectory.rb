# encoding: US-ASCII

require 'ReiserFSUtils'
require 'ReiserFSDirectoryEntry'

module ReiserFS
	
	class Directory
		
		ROOT_DIR = { 'directory_id' => 1, 'object_id' => 2, 'offset' => 0, 'type' => 0 }
    
    attr_accessor :key, :sb
    
    ###################################################################
    # A directory is composed of 2 things: Key and BlockNum
    #  Key is in the form of {doid,oid,offset,type}
    #  BlockNum is what is used to actually instantiate the Block object
    # 
    # Note:  BlockNum can always be computed from Key and the ROOT_DIR
    ###################################################################
		def initialize(sb, key = nil)
			raise "Nil superblock" if sb == nil
			@sb        = sb
		  @key       = key.nil? ? ROOT_DIR : key
		  @leaves    = @sb.getLeafNodes(@key)
		  @dirEntry  = nil
		  @dirItems  = nil
		  
      raise "Key #{Utils.dumpKey(@key)} NOT found" if @leaves.nil?

      @leaves.each do |leaf|
        leaf.getItemHeaders.each do |iheader|
          @dirEntry = DirectoryEntry.new(leaf,iheader,@key)  if Utils.typeIsStat?(leaf.getItemType(iheader))
        end
      end
      
		end

    def findKey(name)
      initDirItems
      if @dirItems.has_key?(name)
        hash = @dirItems[name]
		    return hash['key']
      end

		  return nil
	  end

		def findEntry(name)
      initDirItems
      if @dirItems.has_key?(name)
        hash = @dirItems[name]
		    if !hash.has_key?('dirEntry')
  		    hash['dirEntry'] = createDirectoryEntry(hash['key'])
  		    @dirItems[name] = hash
		    end
		    return hash['dirEntry']
      end
      
		  return nil
	  end

    def globNames
      if @names.nil?
        initDirItems
        @names = @dirItems.keys
        @names.sort!
      end
      
			return @names
    end
    
    #################
    private
    
    def createDirectoryEntry(key)
		  @sb.getLeafNodes(key).each do |leaf|
  		  leaf.getItemHeaders(key).each do |iheader|
          return DirectoryEntry.new(leaf,iheader,key)   if Utils.typeIsStat?(leaf.getItemType(iheader))
  		  end
		  end
		  return nil
    end
    
    def initDirItems
      return @dirItems unless @dirItems.nil?

      @dirItems = Hash.new
      @leaves.each do |leaf|
        leaf.getItemHeaders(@key).each do |ih|
          if Utils.typeIsDirectory?(leaf.getItemType(ih))
            getDirItems(leaf,ih).each do |item|
              name  = item['name']
              @dirItems[name] = item
            end
          end
        end
      end
    end

    ITEM_DIRECTORY = BinaryStruct.new([
      'V',  'offset',
      'V',  'directory_id',
      'V',  'object_id',
      'v',  'location',
      'v',  'state',
    ])
    SIZEOF_ITEM_DIRECTORY = ITEM_DIRECTORY.size

    def getDirItems(b,i)
      item  = b.getItem(i)
      count = b.getItemCount(i)
      last  = 0
      
      dirItems = Array.new
      (1..count).each do |d|
        offset      = SIZEOF_ITEM_DIRECTORY * (d-1)
        length      = SIZEOF_ITEM_DIRECTORY
        dir         = ITEM_DIRECTORY.decode(item[offset,length])
        gen, hash   = item[offset,4].unpack('B7B24')
        dir['gen']  = gen.to_i(2)
        dir['hash'] = hash.to_i(2)
        dir['key']  = { 'directory_id' => dir['directory_id'], 'object_id' => dir['object_id'], 'offset' => 0, 'type' => 0 }
        dir['name'] = getASCIIZ(item[dir['location']..(last-1)])
        last        = dir['location']
        
        dirItems << dir
      end
      return dirItems
    end
    
    def getASCIIZ(data)
      i = data.index("\0")
      return data if i.nil?
      return data[0..i-1]
    end
		
	end

end
