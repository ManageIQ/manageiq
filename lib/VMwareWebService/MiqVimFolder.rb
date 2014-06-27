class MiqVimFolder
    
    attr_reader :name, :invObj
    
    def initialize(invObj, fh)
	    @invObj		= invObj
	    @sic		= invObj.sic
	    
	    @fh			= fh
	    @name		= @fh["name"]
	    @fMor		= @fh["MOR"]
    end
    
    #
	# Called when client is finished using this MiqVimVm object.
	# The server will delete its reference to the object, so the
	# server-side object csn be GC'd
	#
	def release
	    # @invObj.releaseObj(self)
    end

    def reload
    	@fh = @invObj.getMoProp(@fMor)
    end
	
	def fMor
	    return(@fMor)
    end
    
    def fh
        return(@fh)
    end
    
    def registerVM(path, name, pool=nil, host=nil, asTemplate=false)
        hmor = pmor = nil
        hmor = (host.kind_of?(Hash) ? host['MOR'] : host) if host
	    pmor = (pool.kind_of?(Hash) ? pool['MOR'] : pool) if pool
	    	    
		$vim_log.info "MiqVimFolder(#{@invObj.server}, #{@invObj.username}).registerVM: calling registerVM_Task" if $vim_log
	    taskMor = @invObj.registerVM_Task(@fMor, path, name, asTemplate.to_s, pmor, hmor)
		$vim_log.info "MiqVimFolder(#{@invObj.server}, #{@invObj.username}).registerVM: returned from registerVM_Task" if $vim_log
	    $vim_log.debug "MiqVimFolder::registerVM: taskMor = #{taskMor}" if $vim_log
	    waitForTask(taskMor)
    end

	def addStandaloneHost(hostName, userName, password, *args)
		ah = { :force => false, :wait => true, :asConnected => true }
			
		if args.length == 1 && args.first.kind_of?(Hash)
			ah.merge!(args.first)
		elsif args.length > 1
			ah.merge!(Hash[*args])
		end
		
		cspec = VimHash.new('HostConnectSpec') do |cs|
		    cs.force				= ah[:force].to_s
			cs.hostName				= hostName
			cs.userName				= userName
			cs.password				= password
			cs.managementIp			= ah[:managementIp]			unless ah[:managementIp].nil?
			cs.port					= ah[:port]					unless ah[:port].nil?
			cs.sslThumbprint		= ah[:sslThumbprint]		unless ah[:sslThumbprint].nil?
			cs.vimAccountName		= ah[:vimAccountName]		unless ah[:vimAccountName].nil?
			cs.vimAccountPassword	= ah[:vimAccountPassword]	unless ah[:vimAccountPassword].nil?
			cs.vmFolder				= ah[:vmFolder]				unless ah[:vmFolder].nil?
		end
		
		$vim_log.info "MiqVimCluster(#{@invObj.server}, #{@invObj.username}).addStandaloneHost: calling addStandaloneHost_Task" if $vim_log
	    taskMor = @invObj.addStandaloneHost_Task(@fMor, cspec, ah[:asConnected].to_s, ah[:license])
		$vim_log.info "MiqVimCluster(#{@invObj.server}, #{@invObj.username}).addStandaloneHost: returned from addStandaloneHost_Task" if $vim_log
		return taskMor unless ah[:wait]
	    waitForTask(taskMor)
	end # def addStandaloneHost

	def createFolder(fname)
		@invObj.createFolder(@fMor, fname)
	end

	def subFolderMors
		fh['childEntity'].each_with_object([]) do |ce, ra|
			ra << ce if ce.vimType == 'Folder'
		end
	end
    
    def waitForTask(tmor)
	    @invObj.waitForTask(tmor, self.class.to_s)
    end
end
