
class EvmsHash < Hash
	undef_method(:id)   if method_defined?(:id)
	undef_method(:type) if method_defined?(:type)

	attr_accessor :vcoType
	
	def initialize(evmType=nil)
		@evmType = vcoType
		super()
		yield(self) if block_given?
	end
	
	def method_missing(sym, *args)
		key = sym.to_s
		if key[-1, 1] == '='
			self[key[0...-1]] = args[0]
		else
			self[key]
		end
	end
end

class EvmsArray < Array
	attr_accessor :evmType
	
	def initialize(evmType=nil)
		@evmType = evmType
		super()
		yield(self) if block_given?
	end
end
