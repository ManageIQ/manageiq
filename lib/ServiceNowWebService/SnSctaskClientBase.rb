
$:.push(File.dirname(__FILE__))
$:.push("#{File.dirname(__FILE__)}/../util")

require 'SnSctaskService'
require 'MiqDumpObj'

class SnSctaskClientBase < SnSctaskService
		
	@@receiveTimeout = 120
	
	include MiqDumpObj
		
	attr_reader :server
	
	def initialize(server, username, password)
		@server		= server
		@username	= username
		@password	= password
	
		@receiveTimeout = @@receiveTimeout
		
		on_http_client_init do |http_client, headers|
			http_client.ssl_config.verify_mode		= OpenSSL::SSL::VERIFY_NONE
			http_client.ssl_config.verify_callback	= method(:verify_callback).to_proc
			http_client.receive_timeout				= @receiveTimeout
			
			http_client.set_auth nil, @username, @password
			headers['User-Agent'] = "ManageIQ/EVM"
		end
		
		# Uncomment to enable wiredump output.
		# on_log_header { |msg| puts msg }
		# on_log_body   { |msg| puts msg }
	
		super(:uri => "https://#{@server}/sc_task.do?displayvariables=true&displayvalue=all&SOAP", :version => 1)
	end
	
	def self.receiveTimeout=(val)
		@@receiveTimeout = val
	end
	
	def self.receiveTimeout
		@@receiveTimeout
	end
	
	def receiveTimeout=(val)
		@receiveTimeout = val
		http_client.receive_timeout = @receiveTimeout if http_client
	end
	
	def receiveTimeout
		@receiveTimeout
	end
	
	def verify_callback(is_ok, ctx)
        is_ok
    end
	
end # class SnSctaskClientBase
