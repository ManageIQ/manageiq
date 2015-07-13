
$:.push(File.dirname(__FILE__))
$:.push("#{File.dirname(__FILE__)}/../VMwareWebService")

require 'RcuService'
require 'VimTypes'

class RcuClientBase < RcuService
	
	@@receiveTimeout = 120
			
	attr_reader :server
	
	def initialize(server, username, password)
		@server		= server
		@username	= username
		@password	= password
	
		@receiveTimeout = @@receiveTimeout
		
		@requestSpec = RcuHash.new("RequestSpec") do |rs|
			rs.serviceUrl	= "https://#{server}/sdk"
			rs.vcPassword	= password
			rs.vcUser		= username
		end
		
		on_http_client_init do |http_client, headers|
			http_client.ssl_config.verify_mode		= OpenSSL::SSL::VERIFY_NONE
			http_client.ssl_config.verify_callback	= method(:verify_callback).to_proc
			http_client.receive_timeout				= @receiveTimeout
		end
		
		# Uncomment to enable wiredump output.
		# on_log_header { |msg| puts msg }
		# on_log_body   { |msg| puts msg }
	
	  # RCU
		#super(:uri => "https://#{server}:61921/rcu/api", :version => 1)
	  # VSC
		super(:uri => "https://#{server}:8143/kamino/public/api", :version => 1)
	end
	
	def createClones(cloneSpec)
		requestSpec = RcuHash.new("RequestSpec") do |rs|
			rs.cloneSpec	= cloneSpec
			rs.serviceUrl	= @requestSpec.serviceUrl
			rs.vcPassword	= @requestSpec.vcPassword
			rs.vcUser		= @requestSpec.vcUser
		end
		super(requestSpec)
	end
	
	def createDatastore(datastoreSpec)
		super(datastoreSpec, @requestSpec)
	end
	
	def destroyDatastore(datastoreSpec)
		super(datastoreSpec, @requestSpec)
	end
	
	def getMoref(name, type)
		super(name, type, @requestSpec)
	end
	
	def getVmFiles(mor)
		super(mor, @requestSpec)
	end
	
	def getVms(mor)
		super(mor, @requestSpec)
	end
	
	def resizeDatastore(datastoreSpec)
		super(datastoreSpec, @requestSpec)
	end
	
	def rcuMorToVim(rcuMor)
		type, val = rcuMor.split(':')
		VimString.new(val, type)
	end
	
	def vimMorToRcu(vimMor)
		return "#{vimMor.vimType}:#{vimMor}"
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
	
end # class RcuClientBase
