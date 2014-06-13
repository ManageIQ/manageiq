module MiqVimDump
    
    def dumpObj(obj, level=0)
        @globalIndent = "" if !@globalIndent
        @dumpToLog = false if @dumpToLog.nil?
	    if obj.kind_of? Array
            dumpArray(obj, level)
        elsif obj.kind_of? Hash
            dumpHash(obj, level)
        elsif obj.kind_of?(String) || obj.kind_of?(Numeric)
            indentedPrint(obj, level)
        else
            dumpClass(obj, level)
        end
	end
	
	def dumpHash(h, level)
	    h.each do |k, v|
			s = ""
			s = " <#{v.xsiType}>" if v.respond_to?(:xsiType) && !v.xsiType.nil?
	        indentedPrint("Level#{level} (#{v.class.to_s}), #{k}#{s}:", level)
	        dumpObj(v, level+1)
	    end
	end
	
	def dumpArray(a, level)
	    i = 0
	    a.each do |ae|
			s = ""
			s = " <#{ae.xsiType}>" if ae.respond_to?(:xsiType) && !ae.xsiType.nil?
	        indentedPrint("Level#{level} (#{ae.class.to_s}), [#{i}]#{s}:", level)
	        dumpObj(ae, level+1)
	        i += 1
	    end
	end
	
	def dumpClass(obj, level)
	    indentedPrint("*** Object type: " + obj.class.to_s, level)
		return if !obj
		if obj.kind_of?(DateTime)
			indentedPrint("Level#{level}, #{obj.to_s}:", level)
			return
		end
	    obj.instance_variables.each do |ivn|
	        indentedPrint("Level#{level}, #{ivn}:", level)
	        dumpObj(obj.instance_variable_get(ivn), level+1)
	    end
    end
	
	def globalIndent=(val)
	    @globalIndent = val
    end
    
    def dumpToLog=(val)
	    @dumpToLog = val
    end
	
	def indentedPrint(s, i)
	    if @dumpToLog
	        $vim_log.debug @globalIndent + ("    " * i) + s.to_s
        else
	        print @globalIndent + "    " * i
    	    puts s
	    end
	end
	
	def dumpMors
	    inventoryHash.each do | t, moa |
	        puts "#{t}:"
	        moa.each { |mor| puts "\t#{mor}" }
	    end
	end # def dumpMors
	
	def dumpAll
	    accessors = [
    		"hostSystemsByMor",
    		"datacentersByMor",
    		"foldersByMor",
    		"resourcePoolsByMor",
    		"clusterComputeResourcesByMor",
    		"computeResourcesByMor",
    		"virtualMachinesByMor",
    		"dataStoresByMor"
    	]
    	
    	oldGi = @globalIndent
    	@globalIndent = "\t\t"
    	
    	accessors.each do |a|
    	    puts
    	    puts "*" * (a.length + 1)
    	    puts "#{a}:"
    	    self.send(a).each do | k, o |
        	    puts "\t#{k}"
        	    dumpObj(o)
        	end
    	end
    	@globalIndent = oldGi
    end
    
    def dumpHostInfo
        inventoryHash['HostSystem'].each do |hsMor|
            #puts "*** NEW"
            prop = getMoProp(hsMor)
            dumpObj(prop)
        end
    end
    
end # module MiqVimDump
