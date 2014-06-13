class NmaHash < Hash
	undef_method :id		if self.method_defined? :id
	undef_method :type		if self.method_defined? :type
	undef_method :size		if self.method_defined? :size
	
	STRIP_PREFIX = "nma_"
	
	attr_accessor :symKeys
	
	def initialize(symKeys=false, &block)
		@symKeys = symKeys
		super()
		unless block.nil?
			block.arity < 1 ? self.instance_eval(&block) : block.call(self)
			self.default = nil
		end
	end
	
	def to_ary
		return [ self ]
	end
	
	def method_missing(sym, *args)
		key = sym.to_s.sub(/^#{STRIP_PREFIX}/, "").tr('_', '-')
		if key[-1, 1] == '='
			return (self[key[0...-1]] = args[0]) unless @symKeys
			return (self[key[0...-1].to_sym] = args[0])
		elsif args.length == 1
			return (self[key] = args[0]) unless @symKeys
			return (self[key.to_sym] = args[0])
		else
			return self[key] unless @symKeys
			return self[key.to_sym]
		end
	end
end

class NmaArray < Array
	
	def initialize(&block)
		super()
		unless block.nil?
			block.arity < 1 ? self.instance_eval(&block) : block.call(self)
		end
	end
	
end
