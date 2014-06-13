require File.join(File.dirname(__FILE__), "NmaCore")
require File.join(File.dirname(__FILE__), "OntapMethodMap")

class NmaClient
	attr_reader :options, :svrObj
	
	NA_STYLE_LOGIN_PASSWORD		= NmaCore::NA_STYLE_LOGIN_PASSWORD
	NA_STYLE_RPC 				= NmaCore::NA_STYLE_RPC
	NA_STYLE_HOSTSEQUIV			= NmaCore::NA_STYLE_HOSTSEQUIV
	
	NA_SERVER_TRANSPORT_HTTP	= NmaCore::NA_SERVER_TRANSPORT_HTTP
	NA_SERVER_TRANSPORT_HTTPS	= NmaCore::NA_SERVER_TRANSPORT_HTTPS
	
	NA_SERVER_TYPE_FILER		= NmaCore::NA_SERVER_TYPE_FILER
	NA_SERVER_TYPE_NETCACHE		= NmaCore::NA_SERVER_TYPE_NETCACHE
	NA_SERVER_TYPE_AGENT		= NmaCore::NA_SERVER_TYPE_AGENT
	NA_SERVER_TYPE_DFM			= NmaCore::NA_SERVER_TYPE_DFM
	NA_SERVER_TYPE_CLUSTER		= NmaCore::NA_SERVER_TYPE_CLUSTER
	
	include OntapMethodMap
	
	def initialize(opts={}, &block)
		@options = NmaHash.new(true) do
			auth_style		NA_STYLE_LOGIN_PASSWORD
			transport_type	NA_SERVER_TRANSPORT_HTTP
			server_type		NA_SERVER_TYPE_FILER
			port			80
		end
		@options.merge!(opts)
		unless block.nil?
			block.arity < 1 ? @options.instance_eval(&block) : block.call(@options)
		end

		raise "NmaClient: No server specified" if @options.server.nil?
		
		@svrObj = NmaCore.server_open(@options.server, 1, 1)
		NmaCore.server_style(@svrObj, @options.auth_style)
		
		if options.auth_style == NA_STYLE_LOGIN_PASSWORD
			NmaCore.server_adminuser(@svrObj, @options.username, @options.password)
		end
	end
	
	def self.wire_dump
		NmaCore.wire_dump
	end
	
	def self.wire_dump=(val)
		NmaCore.wire_dump = val
	end
	
	def self.verbose
		NmaCore.verbose
	end
	
	def self.verbose=(val)
		NmaCore.verbose = val
	end
	
	def self.logger
		NmaCore.logger
	end
	
	def self.logger=(val)
		NmaCore.logger = val
	end
	
	def method_missing(sym, *args, &block)
		super(sym, args) unless (cmd = map_method(sym))
		
		ah = nil
		if args.length > 0 || !block.nil?
			ah = NmaHash.new
			
			if args.length == 1 && args.first.kind_of?(Hash)
				ah.merge!(args.first)
			elsif args.length > 1
				ah.merge!(Hash[*args])
			end
			
			unless block.nil?
				block.arity < 1 ? ah.instance_eval(&block) : block.call(ah)
			end
		end
		
		return NmaCore.server_invoke(@svrObj, cmd, ah)
	end
	
end # class NmaClient
