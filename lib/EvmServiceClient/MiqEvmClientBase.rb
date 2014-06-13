
$:.push(File.dirname(__FILE__))
$:.push("#{File.dirname(__FILE__)}/../VMwareWebService")

require 'sync'
require 'EvmService'
require 'MiqVimDump'

# require 'profile'

class MiqEvmClientBase < EvmService
	
	@@receiveTimeout = 120
	
	include MiqVimDump
		
	attr_reader :server
	
	def initialize(server)
		@server   = server
	
		@receiveTimeout = @@receiveTimeout
		
		on_http_client_init do |http_client, headers|
			http_client.ssl_config.verify_mode		= OpenSSL::SSL::VERIFY_NONE
			http_client.ssl_config.verify_callback	= method(:verify_callback).to_proc
			http_client.receive_timeout				= @receiveTimeout
		end
		
		# Uncomment to enable wiredump output.
		# on_log_header { |msg| puts msg }
		# on_log_body   { |msg| puts msg }
	
		super(:uri => "https://#{@server}/vmdbws/api", :version => 1)
		
		@connLock	= Sync.new
	end
	
	def self.receiveTimeout=(val)
		@@receiveTimeout = val
	end
	
	def self.receiveTimeout
		@@receiveTimeout
	end
	
	def receiveTimeout=(val)
		@connLock.synchronize(:EX) do
			@receiveTimeout = val
			http_client.receive_timeout = @receiveTimeout if http_client
		end
	end
	
	def receiveTimeout
		@connLock.synchronize(:SH) do
			@receiveTimeout
		end
	end
	
	def verify_callback(is_ok, ctx)
        is_ok
    end
	
end # class MiqEvmClientBase
