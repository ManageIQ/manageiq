
$:.push(File.dirname(__FILE__))
$:.push("#{File.dirname(__FILE__)}/../VMwareWebService_hs")

require 'sync'
require 'VcoService'
require 'MiqVimDump'

# require 'profile'

class MiqVcoClientBase < VcoService
	
	@@receiveTimeout = 120
	
	include MiqVimDump
	
	attr_reader :server, :username, :password
	
	def initialize(server, username, password)
		@server   = server
	    @username = username
	    @password = password
	
		@receiveTimeout = @@receiveTimeout
		
		on_http_client_init do |http_client, headers|
			http_client.ssl_config.verify_mode		= OpenSSL::SSL::VERIFY_NONE
			http_client.ssl_config.verify_callback	= method(:verify_callback).to_proc
			http_client.receive_timeout				= @receiveTimeout
		end
		
		on_log_header { |msg| puts msg }
		on_log_body   { |msg| puts msg }
	
		super(:uri => "http://#{@server}:8280/vmware-vmo-webcontrol/webservice", :version => 1)
		
		@connected	= false
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
	
	def executeWorkflow(wfId, inputs, wait=true)
		rv = super(wfId, @username, @password, inputs)
		return(rv) unless wait
		
		wfId = rv.id
		loop do
			rv = getWorkflowTokenForId(wfId)
			break if rv.globalState != 'running'
			sleep 4
		end
		return(rv)
	end
	
	def find(type, query=nil)
		super(type, query, @username, @password)
	end
	
	def findByFilter(type, filter)
		fv = find(type)
		ra = Array.new
		return(ra) if fv.totalCount == 0
		
		nmatch = filter.keys.length
		
		items = fv.elements.item
		items = [ items ] unless items.kind_of?(Array)
		
		items.each do |ai|
			matches = 0
			filter.each do |pn, pv|
				ai.properties.item.each do |p|
					next if p.name != pn || p.value != pv
					matches += 1
					break
				end
			end
			ra << ai if matches == nmatch
		end
		return(ra)
	end
	
	def findRelation(parentType, parentId, relationName)
		super(parentType, parentId, relationName, @username, @password)
	end
	
	def getAllWorkflows
		super(@username, @password)
	end
	
	def getWorkflowTokenForId(workflowTokenId)
		super(workflowTokenId, @username, @password)
	end
	
	def getWorkflowTokenStatus(workflowTokenIds)
		super(workflowTokenIds, @username, @password)
	end
	
	def getWorkflowsWithName(workflowName)
		super(workflowName, @username, @password)
	end
	
	def getWorkflowForId(workflowId)
		super(workflowId, @username, @password)
	end
	
	def verify_callback(is_ok, ctx)
        is_ok
    end
	
end # class MiqVimClientBase
