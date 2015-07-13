
class RcuHash < Hash
	undef_method(:id)   if method_defined?(:id)
	undef_method(:type) if method_defined?(:type)
	
	attr_accessor	:rcuType
	attr_reader		:orderedKeys
	
	def initialize(rcuType=nil)
		@rcuType = rcuType
		@orderedKeys = []
		super()
		yield(self) if block_given?
	end
	
	def each
		@orderedKeys.each do |k|
			yield(k, self.fetch(k, nil))
		end
	end
	
	def []=(key, val)
		@orderedKeys << key unless @orderedKeys.include?(key)
		super
	end
	
	def method_missing(sym, *args)
		key = sym.to_s
		if key[-1, 1] == '='
			key = key[0...-1]
			self[key] = args[0]
		else
			self[key]
		end
	end
end

class RcuArray < Array
	attr_accessor :rcuType
	
	def initialize(rcuType=nil)
		@rcuType = rcuType
		super()
		yield(self) if block_given?
	end
end

class RcuVal < String
	attr_accessor :xsiType
	
	def initialize(val="", xsiType="xsd:string")
		@xsiType = xsiType
		super(val)
		yield(self) if block_given?
	end
end
