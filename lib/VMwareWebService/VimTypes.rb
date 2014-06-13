require 'VimConstants'
autoload :VimMappingRegistry, "VimMappingRegistry"


class VimHash < Hash
	undef_method(:id)   if method_defined?(:id)
	undef_method(:type) if method_defined?(:type)
	undef_method(:size) if method_defined?(:size)
	
	def initialize(xsiType=nil, vimType=nil)
		self.xsiType = xsiType
		self.vimType = vimType
		super()
		self.default = nil
		yield(self) if block_given?
	end
	
	def each_arg
		raise "No arg map for #{self.xsiType}" if !(am = VimMappingRegistry.args(self.xsiType))
		am.each do |a|
			next if !self.has_key?(a)
			yield(a, self[a])
		end
	end

	def vimType
		@vimType.nil? ? nil : @vimType.to_s
	end

	def vimType=(val)
		@vimType = val.nil? ? nil : val.to_sym
	end

	def xsiType
		@xsiType.nil? ? nil : @xsiType.to_s
	end

	def xsiType=(val)
		@xsiType = val.nil? ? nil : val.to_sym
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

class VimArray < Array
	def initialize(xsiType=nil, vimType=nil)
		self.xsiType = xsiType
		self.vimType = vimType
		super()
		yield(self) if block_given?
	end

	def vimType
		@vimType.nil? ? nil : @vimType.to_s
	end

	def vimType=(val)
		@vimType = val.nil? ? nil : val.to_sym
	end

	def xsiType
		@xsiType.nil? ? nil : @xsiType.to_s
	end

	def xsiType=(val)
		@xsiType = val.nil? ? nil : val.to_sym
	end
end

class VimString < String
	#
	# vimType and xsiType arg positions are switched here because
	# most strings are MORs, and this makes it easier to set the
	# vimType of the MOR.
	#
	def initialize(val="", vimType=nil, xsiType=nil)
		self.xsiType = xsiType
		self.vimType = vimType
		super(val)
		yield(self) if block_given?
	end

	def vimType
		@vimType.nil? ? nil : @vimType.to_s
	end

	def vimType=(val)
		@vimType = val.nil? ? nil : val.to_sym
	end

	def xsiType
		@xsiType.nil? ? nil : @xsiType.to_s
	end

	def xsiType=(val)
		@xsiType = val.nil? ? nil : val.to_sym
	end
end

class VimFault < RuntimeError
	attr_accessor :vimFaultInfo
	
	def initialize(vimObj)
		@vimFaultInfo = vimObj
		super(@vimFaultInfo.localizedMessage)
	end
end
