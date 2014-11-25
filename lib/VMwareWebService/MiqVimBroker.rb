require 'drb'
require 'drb/acl'
require 'sync'

require 'MiqVimInventory'
require 'VimTypes'

class MiqVimBroker
	
	class VimBrokerIdConv < DRb::DRbIdConv
		def to_obj(ref)
			obj = super(ref)
			if obj.respond_to?(:connectionRemoved?) && obj.connectionRemoved?
				$vim_log.info "VimBrokerIdConv: #{obj.class.name} - connection removed"
				raise RangeError, "#{ref} is recycled object"
			end
			return obj
		end
	end
	
	attr_reader :shuttingDown
	
	MB = 1048576
	DRb::DRbServer.default_load_limit(50*MB)
    
    @@preLoad		= false
    @@debugUpdates	= false
	@@classModed	= false
	@@notifyMethod	= nil
	@@updateDelay	= nil
	@@cacheScope	= :cache_scope_full
	@@selectorHash	= {}
        
    def initialize(mode=:client, port=9001)
        if mode == :client
			require 'rubygems'
			require 'httpclient'	# needed for exception classes
			require 'MiqVimDump'
			require 'MiqVimVdlMod'
			#
			# Modify the meta-class of DRb::DRbObject
			# so we can alias class methods
			#
			if !@@classModed
				class <<DRb::DRbObject
					alias new_with_original new_with
					def new_with(uri, ref)
						obj = new_with_original(uri, ref)
						obj.instance_eval("extend MiqVimVdlVcConnectionMod") if obj.respond_to?(:vdlVcConnection)
						obj.registerBrokerObj($$) if obj.respond_to?(:registerBrokerObj)
						return(obj)
					end
				end

				DRb.instance_variable_set(:@mutex, Sync.new)
				DRb::DRbConn.instance_variable_set(:@mutex, Sync.new)
				@@classModed = true
 			end
			
            @mode = :client

			# start DRb service if it hasn't been started before
			begin
			    DRb.current_server
			rescue DRb::DRbServerNotFound
			    DRb.start_service
			end
            @broker = DRbObject.new(nil, "druby://127.0.0.1:#{port}")
        elsif mode == :server
			unless @@classModed
				DRb.instance_variable_set(:@mutex, Sync.new)
				DRb::DRbConn.instance_variable_set(:@mutex, Sync.new)
			end
			@@classModed = true
			
            require 'MiqVimBrokerMods' # only needed by the server
            @mode = :server
			@shuttingDown = false
			
			@connectionHash = Hash.new
			@lockHash = Hash.new		# Protects individual @connectionHash entries
	        @connectionLock = Sync.new	# Protects @lockHash
	
			@configLock		= Sync.new
			@selectorHash	= @@selectorHash
			@cacheScope		= @@cacheScope
			
            #$SAFE = 1
			acl = ACL.new( %w[ deny all allow 127.0.0.1/32 ] )
			DRb.install_acl(acl)
			DRb.start_service("druby://127.0.0.1:#{port}", self, { :idconv => VimBrokerIdConv.new })
        else
            raise "MiqVimBroker: unrecognized mode #{mode}"
        end
    end

	def self.cacheScope
		@@cacheScope
	end
	
	def self.cacheScope=(val)
		@@cacheScope = val
	end
	
	def cacheScope
		@cacheScope
	end
	
	def cacheScope=(val)
		@cacheScope = val
	end

	#
	# The setSelector() and removeSelector() class methods, set the Selector specs that will be inherited
	# by all subsequent MiqVimBroker instances.
	#
	# Should only be called on the server-side.
	#
	def self.setSelector(selSpec)
		raise "MiqVimBroker.setSelector: selSpec must be a hash, received #{selSpec.class}" unless selSpec.kind_of?(Hash)
		selSpec.each_key do |k|
			raise "MiqVimBroker.setSelector: selSpec keys must be symbols, received #{k.class}" unless k.kind_of?(Symbol)
		end
		ov = nil
		selSpec.each_value do |v|
			if v.kind_of?(Array)
				v.each do |vv|
					unless vv.kind_of?(String)
						ov = vv
						break
					end
				end
			else
				ov = v unless v.kind_of?(String)
			end
			raise "MiqVimBroker.setSelector: selSpec values must be strings or arrays of strings, received #{ov.class}" unless ov.nil?
		end
		@@selectorHash.merge!(selSpec)
	end
	
	def self.removeSelector(selName)		
		remKeys = nil
		if selName.kind_of?(Symbol)
			remKeys = [ selName ]
		elsif selName.kind_of?(Hash)
			remKeys = selName.keys
		elsif selName.kind_of?(Array)
			remKeys = selName
		else
			raise "MiqVimBroker.removeSelector: selName must be a symbol, hash or array, received #{selName.class}"
		end
		remKeys.each do |rk|
			raise "MiqVimBroker.removeSelector: keys must be symbols, received #{rk.class}" unless rk.kind_of?(Symbol)
		end
		
		remKeys.each do |rk|
			@@selectorHash.delete(rk)
		end
	end

	#
	# The setSelector() and removeSelector() instance methods, set the Selector specs that will be inherited
	# by all subsequent connections.
	#
	def setSelector(selSpec)
		if @mode == :client
            return @broker.setSelector(selSpec)
		end
		
		raise "setSelector: selSpec must be a hash, received #{selSpec.class}" unless selSpec.kind_of?(Hash)
		selSpec.each_key do |k|
			raise "setSelector: selSpec keys must be symbols, received #{k.class}" unless k.kind_of?(Symbol)
		end
		ov = nil
		selSpec.each_value do |v|
			if v.kind_of?(Array)
				v.each do |vv|
					unless vv.kind_of?(String)
						ov = vv
						break
					end
				end
			else
				ov = v unless v.kind_of?(String)
			end
			raise "setSelector: selSpec values must be strings or arrays of strings, received #{ov.class}" unless ov.nil?
		end
		
		@configLock.synchronize(:EX) do
			@selectorHash.merge!(selSpec)
		end
	end
	
	def removeSelector(selName)
		if @mode == :client
            return @broker.removeSelector(selName)
		end
		
		remKeys = nil
		if selName.kind_of?(Symbol)
			remKeys = [ selName ]
		elsif selName.kind_of?(Hash)
			remKeys = selName.keys
		elsif selName.kind_of?(Array)
			remKeys = selName
		else
			raise "removeSelector: selName must be a symbol, hash or array, received #{selName.class}"
		end
		remKeys.each do |rk|
			raise "removeSelector: keys must be symbols, received #{rk.class}" unless rk.kind_of?(Symbol)
		end
		
		@configLock.synchronize(:EX) do
			remKeys.each do |rk|
				@selectorHash.delete(rk)
			end
		end
	end
    
    def self.preLoad=(val)
        @@preLoad = val
    end
    
    def self.preLoad
        @@preLoad
    end
    
    def self.debugUpdates=(val)
        @@debugUpdates = val
    end
    
    def self.debugUpdates
        @@debugUpdates
    end

	#
	# Instance method changes the debugUpdates value of existing connections.
	#
	def debugUpdates=(val)
		return if @mode == :client
		@connectionHash.keys.each do |key|
			@lockHash[key].synchronize(:SH) do
				next if (vim = @connectionHash[key]).nil?
				vim.debugUpdates = val
			end
		end
	end

	def self.notifyMethod=(val)
        @@notifyMethod = val
    end
    
    def self.notifyMethod
        @@notifyMethod
    end

	#
	# Instance method changes the notifyMethod value of existing connections.
	#
	def notifyMethod=(val)
		return if @mode == :client
		@connectionHash.keys.each do |key|
			@lockHash[key].synchronize(:SH) do
				next if (vim = @connectionHash[key]).nil?
				vim.notifyMethod = val
			end
		end
	end

	def self.updateDelay=(val)
		@@updateDelay = val
	end
	
	def self.updateDelay
		@@updateDelay
	end
	
	#
	# Instance method changes the updateDelay value of existing connections.
	#
	def updateDelay=(val)
		return if @mode == :client
		@connectionHash.keys.each do |key|
			@lockHash[key].synchronize(:SH) do
				next if (vim = @connectionHash[key]).nil?
				vim.updateDelay = val
			end
		end
	end

	def releaseSession(sessionId)
		if @mode == :client
			$vim_log.info "Client releaseSession: #{sessionId}"
            @broker.releaseSession(sessionId)
        else
			$vim_log.info "Server releaseSession: #{sessionId}"
			$miqBrokerObjRegistry[sessionId].dup.each { |o| o.release }
		end
	end
	
	def objectCounts
		if @mode == :client
            @broker.objectCounts
        else
			$miqBrokerObjRegistryLock.synchronize(:SH) do
				return $miqBrokerObjCounts.dup
			end
		end
	end
	
	def self.connectionKey(server, username)
		return "#{server}_#{username}"
	end
	
	def connectionKey(server, username)
		self.class.connectionKey(server, username)
	end
	
	def lockHash(key)
		@connectionLock.synchronize(:EX) do
			raise "MiqVimBroker is shutting down" if @shuttingDown
			#
			# Once set, @lockHash[key] doesn't change.
			#
			@lockHash[key] ||= Sync.new
		end
	end
	
	def connSync(mode, server, username, &block)
		key = connectionKey(server, username)
		lock = lockHash(key)
		
		begin
			lock.sync_lock(mode)
			if block.arity < 1
				block.call
			elsif block.arity == 1
				block.call(key)
			elsif block.arity == 2
				block.call(key, @connectionHash[key])
			else
				raise "MiqVimBroker.connSync: unexpected number of block args: #{block.arity}"
			end
		ensure
			lock.sync_unlock
		end
	end
	
	def connTrySync(mode, server, username, &block)
		key = connectionKey(server, username)
		lock = lockHash(key)
		
		begin
			locked = lock.sync_try_lock(mode)
			return unless locked
			
			if block.arity < 1
				block.call
			elsif block.arity == 1
				block.call(key)
			elsif block.arity == 2
				block.call(key, @connectionHash[key])
			else
				raise "MiqVimBroker.connTrySync: unexpected number of block args: #{block.arity}"
			end
		ensure
			lock.sync_unlock if locked
		end
	end
    
	def getMiqVim(server, username, password)
        if @mode == :client
            vim = @broker.getMiqVim(server, username, password)
            vim.instance_eval("extend MiqVimDump")
			vim.instance_eval("extend MiqVimVdlConnectionMod")
			return(vim)
        else # :server
			connSync(:EX, server, username) do |key, vim|
				if vim
					$vim_log.info "MiqVimBroker.getMiqVim: found connection for #{key}"
					if vim.isAlive?
						$vim_log.info "MiqVimBroker.getMiqVim: returning existing connection for #{key}"
						return(vim)
					end
					$vim_log.info "MiqVimBroker.getMiqVim: existing connection for #{key} not alive"
					removeMiqVimSS(key, vim)
				end
				begin
	               	vim = DMiqVim.new(server.untaint, username, password, self, @@preLoad, @@debugUpdates, @@notifyMethod, @cacheScope)
					vim.updateDelay = @@updateDelay if @@updateDelay
					vim.setSelector(@selectorHash) unless @selectorHash.empty?
					$vim_log.info "MiqVimBroker.getMiqVim: returning new connection for #{key}"
					@connectionHash[key] = vim
					return(vim)
				rescue Exception => err
					$vim_log.error "MiqVimBroker.getMiqVim: failed to create new connection for #{key}"
					$vim_log.error "#{err.class}: #{err}"
					if $vim_log.debug?
						$vim_log.debug "Stack trace START"
						$vim_log.debug err.backtrace.join("\n")
						$vim_log.debug "Stack trace END"
					end
					raise err
				end
			end
		end # :server
    end
    
    def removeMiqVim(server, username)
        if @mode == :client
			@broker.removeMiqVim(server, username)
			return
		end
		
		# server
		log_prefix = "MiqVimBroker.removeMiqVim"
		$vim_log.info "#{log_prefix}: client request to remove connection (#{server}, #{username})...Starting"
		connSync(:EX, server, username) do |key, vim|
			removeMiqVimSS(key, vim)
		end
		$vim_log.info "#{log_prefix}: client request to remove connection (#{server}, #{username})...Comolete"
    end

	#
	# Server-side removal of VIM connection.
	# Must be called within a connSync(:EX, server, username) context.
	#
	def removeMiqVimSS(key, vim)
		log_prefix = "MiqVimBroker.removeMiqVimSS"
		$vim_log.info "#{log_prefix}: removing connection for #{key}...Starting"

		if @shuttingDown
			$vim_log.info "#{log_prefix}: not removing connection for #{key} - broker shutting down"
			return
		end
		if vim.nil?
			$vim_log.info "#{log_prefix}: not removing connection for #{key} - connection not found"
			return
		end
		if vim.connectionRemoved?
			$vim_log.info "#{log_prefix}: not removing connection for #{key} - connection already removed"
			return
		end
		
		vim.shutdownConnection
		$miqBrokerObjRegistryByConn[key].dup.each { |o| o.release }
		@connectionHash.delete(key)
		vim.connectionRemoved

		$vim_log.info "#{log_prefix}: removing connection for #{key}...Complete"
	end

	def shutdown
		raise "MiqVimBroker: shutdown cannot be called from client" if @mode == :client
		log_prefix = "MiqVimBroker.shutdown"
		$vim_log.info "#{log_prefix}...Starting"
		@connectionLock.synchronize(:EX) do
			@shuttingDown = true
		end
		@connectionHash.keys.each do |id|
			@lockHash[id].synchronize(:EX) do
				next if (vim = @connectionHash[id]).nil?
				vim.shutdownConnection
				@connectionHash.delete(id)
				vim.connectionRemoved
			end
		end
		DRb.stop_service
		$vim_log.info "#{log_prefix}...Complete"
	end
	
	def serverAlive?
		if @mode == :client
			begin
				return @broker.serverAlive?
			rescue DRb::DRbConnError => err
				return false
			end
		end
		return true
	end
	
	def connectionInfo
		return @broker.connectionInfo if @mode == :client
		
		# server
		ra = []
		@connectionHash.keys.each do |key|
			@lockHash[key].synchronize(:SH) do
				next if (vim = @connectionHash[key]).nil?
				ra << [vim.server, vim.username]
			end
		end
		return ra
	end
	
	def logStatus
		if @mode == :client
			@broker.logStatus
			return
		end
		
		# server
		$vim_log.info "MiqVimBroker status start"
		$vim_log.info "\tMiqVimBroker: Threads = #{Thread.list.length}"
		
		$vim_log.info "\tMiqVimBroker client object counts by type:"
		objectCounts.each { |t, c| $vim_log.info "\t\t#{t}: #{c}" }
		$vim_log.info "\tEnd MiqVimBroker client object counts by type"
		
		brokerCacheSz = 0
		
		$vim_log.info "\tMiqVimBroker open connections: #{@connectionHash.keys.length}"
		@connectionHash.keys.each do |k|
			@lockHash[k].synchronize(:SH) do
				next if (vim = @connectionHash[k]).nil?
				$vim_log.info "\t\tMiqVimBroker connection #{k} cache counts:"
				# vim.logCacheCounts("\t\t\t")
				brokerCacheSz += vim.cacheStats("\t\t\t#{k} - ")
				$vim_log.info "\t\tEnd MiqVimBroker connection #{k} cache counts"
			end
		end
		$vim_log.info "\tEnd MiqVimBroker open connections"
		$vim_log.info "MiqVimBroker status end - Total broker cache size = #{brokerCacheSz}"
	end

	def forceGC
		if @mode == :client
			@broker.forceGC
			return
		end

		log_prefix = "MiqVimBroker.forceGC"
		$vim_log.info "#{log_prefix}: GC.start...Starting"
		GC.start
		$vim_log.info "#{log_prefix}: GC.start...Complete"
	end

end # class MiqVimBroker
