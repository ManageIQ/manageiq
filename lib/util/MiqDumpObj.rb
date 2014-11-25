module MiqDumpObj

	def initialize(pref="", excludeIv={})
		@prefix = pref
		@excludeIv = excludeIv
	end
	
	def dumpObj(obj, level=0)
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
	        indentedPrint("Level#{level} (#{v.class}), #{k}:", level)
	        dumpObj(v, level+1)
	    end
	end
	
	def dumpArray(a, level)
	    i = 0
	    a.each do |ae|
	        indentedPrint("Level#{level} (#{ae.class}), [#{i}]:", level)
	        dumpObj(ae, level+1)
	        i += 1
	    end
	end
	
	def dumpClass(obj, level)
		className = obj.class.name
	    indentedPrint("**** Object type: #{className}", level)
		return if !obj
		if obj.kind_of?(DateTime)
			indentedPrint("Level#{level}, #{obj}:", level)
			return
		end
		eiv = @excludeIv[className]
	    obj.instance_variables.each do |ivn|
	    	next if eiv && eiv[ivn]
	        indentedPrint("Level#{level}, #{ivn}:", level)
	        dumpObj(obj.instance_variable_get(ivn), level+1)
	    end
    end
	
	def indentedPrint(s, i)
        print "#{@prefix}#{'    ' * i}"
   	    puts s
	end
	
end # module MiqDumpObj
