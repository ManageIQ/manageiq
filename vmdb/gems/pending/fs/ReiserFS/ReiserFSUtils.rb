module ReiserFS
	
	class Utils
	  def self.dumpKey(key, label = nil)
      return "#{label}:\t\{#{key['directory_id']},#{key['object_id']},#{key['offset']},#{key['type']}\}"
    end
    
    def self.typeIsStat?(t)
      return t == 0
    end
    
    def self.typeIsDirectory?(t)
      return true if t == 500
      return true if t == 3
      return false
    end

    def self.typeIsDirect?(t)
      return true if t == -1
      return false
    end

    def self.typeIsIndirect?(t)
      return true if t == -2
      return false
    end

    
    def self.type2text(t)
      case t
      when -1
        return 'direct'
      when -2
        return 'indirect'
      when 0
        return 'stat'
      when 500
        return 'directory'
      when 555
        return 'any'
      else
        raise "Unrecognized Type #{t}"
      end
    end
    
    def self.type2integer(t)
      case t
      when 0x20000000, 0xFFFFFFFF
        return -1
        
      when 0x10000000, 0xFFFFFFFE
        return -2
        
      end
      
      return t
    end
    
    def self.getKeyDirectoryID(k)
      return k['directory_id']
    end
    
    def self.getKeyObjectID(k)
      return k['object_id']
    end
    
    def self.getKeyOffset(k)
      return k['offset']
    end
    
    def self.getKeyType(k)
      return k['type']
    end
    
    def self.compareKeys(a, b, fuzzy=true)
      # Compare directory IDs
      return (-1) if (a['directory_id'] <  b['directory_id'])
      return (+1) if (a['directory_id'] >  b['directory_id'])
      
      # Compare Object IDs
      return (-1) if (a['object_id']    <  b['object_id'])
      return (+1) if (a['object_id']    >  b['object_id'])
      
      if fuzzy == false
        # Compare Offsets
        return (-1) if (a['offset']       <  b['offset'])
        return (+1) if (a['offset']       >  b['offset'])
      
        # Compare Types
        return (-1) if (a['type']         <  b['type'])
        return (+1) if (a['type']         >  b['type'])
      end
      
      return  0
    end
    
  end
  
end
