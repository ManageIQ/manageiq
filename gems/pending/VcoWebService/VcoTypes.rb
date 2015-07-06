
class VcoHash < Hash
	undef_method(:id)   if method_defined?(:id)
	undef_method(:type) if method_defined?(:type)
	
	attr_accessor :vcoType
	
	def initialize(vcoType=nil)
		@vcoType = vcoType
		super()
		yield(self) if block_given?
	end
	
	# def each_arg
	# 	raise "No arg map for #{@xsiType}" if !(am = VimMappingRegistry.args(@xsiType))
	# 	am.each do |a|
	# 		next if !self.has_key?(a)
	# 		yield(a, self[a])
	# 	end
	# end
	
	def method_missing(sym, *args)
		key = sym.to_s
		if key[-1, 1] == '='
			self[key[0...-1]] = args[0]
		else
			self[key]
		end
	end
end

class VcoArray < Array
	attr_accessor :vcoType
	
	def initialize(vcoType=nil)
		@vcoType = vcoType
		super()
		yield(self) if block_given?
	end
end
