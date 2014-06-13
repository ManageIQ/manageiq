class MiqVimCluster
    
    attr_reader :name, :invObj
    
    def initialize(invObj, ch)
	    @invObj		= invObj
	    @sic		= invObj.sic
	    
	    @ch			= ch
	    @name		= @ch["name"]
	    @cMor		= @ch["MOR"]
    end
    
	def release
	    # @invObj.releaseObj(self)
    end
	
	def cMor
	    return(@cMor)
    end
    
    def ch
        return(@ch)
    end

	def addHost(hostName, userName, password, *args)
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
		
		$vim_log.info "MiqVimCluster(#{@invObj.server}, #{@invObj.username}).addHost: calling addHost_Task" if $vim_log
	    taskMor = @invObj.addHost_Task(@cMor, cspec, ah[:asConnected].to_s, ah[:resourcePool], ah[:license])
		$vim_log.info "MiqVimCluster(#{@invObj.server}, #{@invObj.username}).addHost: returned from addHost_Task" if $vim_log
		return taskMor unless ah[:wait]
	    waitForTask(taskMor)
	end # def addHost
    
    def waitForTask(tmor)
	    @invObj.waitForTask(tmor, self.class.to_s)
    end
end
