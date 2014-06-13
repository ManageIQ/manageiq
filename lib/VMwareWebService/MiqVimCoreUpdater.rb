require 'MiqVimClientBase'
require 'MiqVimDump'
require 'VimPropMaps'

class MiqVimCoreUpdater < MiqVimClientBase
	
	include VimPropMaps
	include MiqVimDump
	
	def initialize(server, username, password, propMap=nil)
	    super(server, username, password)
	
		@propMap    = propMap || VimCoreUpdaterPropMap
		if @v4
			@propMap = dupProps(@propMap)
			addProperty(:VirtualMachine, "runtime.memoryOverhead")
		end
		
		@propCol    = @sic.propertyCollector
		@rootFolder = @sic.rootFolder
		@objectSet  = objectSet
		@updateSpec	= updateSpec
		
		@debugUpdates = false
		
		connect
		
		@alive = true
	end
	
	def addProperty(key, property)
		return if (pm = @propMap[key]).nil?
		property.split('.').each { |p| return if pm.include?(p) }
		@propMap[key][:props] << property
	end
	
	#
	# Construct an ObjectSpec to traverse the entire VI inventory tree.
	#
	def objectSet
		#
		# Traverse VirtualApp to Vm.
		#
		virtualAppTs = VimHash.new("TraversalSpec") do |ts|
			ts.name			= "virtualAppTraversalSpec"
			ts.type			= "VirtualApp"
			ts.path			= "vm"
			ts.skip			= "false"
		end unless @v2
		
	    #
	    # Traverse ResourcePool to ResourcePool and VirtualApp.
	    #
	    resourcePoolTs = VimHash.new("TraversalSpec") do |ts|
			ts.name			= "resourcePoolTraversalSpec"
			ts.type			= "ResourcePool"
			ts.path			= "resourcePool"
			ts.skip			= "false"
			ts.selectSet	= VimArray.new("ArrayOfSelectionSpec") do |ssa|
				ssa << VimHash.new("SelectionSpec") { |ss| ss.name = "resourcePoolTraversalSpec" }
			end
		end

        #
	    # Traverse ComputeResource to ResourcePool.
	    #
		computeResourceRpTs = VimHash.new("TraversalSpec") do |ts|
			ts.name        = "computeResourceRpTraversalSpec"
			ts.type        = "ComputeResource"
			ts.path        = "resourcePool"
			ts.skip        = "false"
			ts.selectSet   = VimArray.new("ArrayOfSelectionSpec") do |ssa|
				ssa << VimHash.new("SelectionSpec") { |ss| ss.name = "resourcePoolTraversalSpec" }
			end
		end

        #
	    # Traverse ComputeResource to host.
	    #
		computeResourceHostTs = VimHash.new("TraversalSpec") do |ts|
			ts.name			= "computeResourceHostTraversalSpec"
			ts.type			= "ComputeResource"
			ts.path			= "host"
			ts.skip			= "false"
		end
		   
		#
	    # Traverse Datacenter to host folder.
	    #                     
		datacenterHostTs = VimHash.new("TraversalSpec") do |ts|
			ts.name			= "datacenterHostTraversalSpec"
			ts.type			= "Datacenter"
			ts.path			= "hostFolder"
			ts.skip			= "false"
			ts.selectSet	= VimArray.new("ArrayOfSelectionSpec") do |ssa|
				ssa << VimHash.new("SelectionSpec") { |ss| ss.name = "folderTraversalSpec" }
			end
		end

        #
	    # Traverse Datacenter to VM folder.
	    #
		datacenterVmTs = VimHash.new("TraversalSpec") do |ts|
			ts.name			= "datacenterVmTraversalSpec"
			ts.type			= "Datacenter"
			ts.path			= "vmFolder"
			ts.skip			= "false"
			ts.selectSet	= VimArray.new("ArrayOfSelectionSpec") do |ssa|
				ssa << VimHash.new("SelectionSpec") { |ss| ss.name = "folderTraversalSpec" }
			end
		end
		
		#
	    # Traverse Datacenter to Datastore.
	    #
		datacenterDsTs = VimHash.new("TraversalSpec") do |ts|
			ts.name			= "datacenterDsTraversalSpec"
			ts.type			= "Datacenter"
			ts.path			= "datastore"
			ts.skip			= "false"
		end

        #
        # Traverse Folder to children.
        #
		folderTs = VimHash.new("TraversalSpec") do |ts|
			ts.name			= "folderTraversalSpec"
			ts.type			= "Folder"
			ts.path			= "childEntity"
			ts.skip			= "false"
			ts.selectSet	= VimArray.new("ArrayOfSelectionSpec") do |ssa|
				ssa		<< VimHash.new("SelectionSpec") { |ss| ss.name = "folderTraversalSpec" }
				ssa		<< datacenterHostTs
				ssa		<< datacenterVmTs
				ssa		<< datacenterDsTs
				ssa		<< computeResourceRpTs
				ssa		<< computeResourceHostTs
				ssa		<< resourcePoolTs
				ssa		<< virtualAppTs unless @v2
			end
		end
		
		aOobjSpec = VimArray.new("ArrayOfObjectSpec") do |osa|
			osa		<< VimHash.new("ObjectSpec") do |os|
				os.obj			= @sic.rootFolder
				os.skip			= "false"
				os.selectSet	= VimArray.new("ArrayOfSelectionSpec") { |ssa| ssa << folderTs }
			end
		end
		
		return(aOobjSpec)
	end # def objectSet
	
	def updateSpec
		VimHash.new("PropertyFilterSpec") do |pfs|
			pfs.propSet = VimArray.new("ArrayOfPropertySpec") do |psa|
				@propMap.each do |type, h|
					psa << VimHash.new("PropertySpec") do |ps|
						ps.type		= type
						ps.all		= h[:props].nil?.to_s
						ps.pathSet	= h[:props] if h[:props]
					end
			    end
			end
			pfs.objectSet = @objectSet
		end
	end
	
	def monitorUpdates(&block)
		log_prefix = "#{self.class.name}.monitorUpdates"
		@umPropCol      = nil
		@filterSpecRef  = nil
		@monitor        = true
		@debugUpdates   = false if @debugUpdates.nil?
		@dumpToLog      = true  if @debugUpdates

		$vim_log.debug "#{log_prefix}: debugUpdates = #{@debugUpdates}"

		trap(:TERM) { $vim_log.info "#{log_prefix}: ignoring SIGTERM" }

		begin
			@umPropCol     = @sic.propertyCollector
			@filterSpecRef = createFilter(@umPropCol, @updateSpec, "true")

			version = nil

			while @monitor do
				updates_version = doUpdate(version, &block)
				next if updates_version.nil?
				version = updates_version
				sleep @updateDelay if @updateDelay
			end # while @monitor
		rescue SignalException => err
			# Ignore signals, except TERM
		rescue => herr
			if herr.respond_to?(:reason) && herr.reason == 'The task was canceled by a user.'
				$vim_log.info "#{log_prefix}: waitForUpdates canceled"
			else
				$vim_log.error "******* #{herr.class.to_s}"
				$vim_log.error herr.to_s
				$vim_log.error herr.backtrace.join("\n") unless herr.kind_of?(HTTPClient::ReceiveTimeoutError) # already logged in monitorUpdatesInitial or monitorUpdatesSince
				raise herr
			end
		ensure
			if isAlive?
				if @filterSpecRef
					$vim_log.info "#{log_prefix}: calling destroyPropertyFilter...Starting"
					destroyPropertyFilter(@filterSpecRef)
					$vim_log.info "#{log_prefix}: calling destroyPropertyFilter...Complete"
				end
				$vim_log.info "#{log_prefix}: disconnecting..."
				disconnect
				$vim_log.info "#{log_prefix}: disconnected"
			end
			@filterSpecRef = nil
			# @umPropCol     = nil
		end
	end # def monitorUpdates
	
	def doUpdate(version, &block)
		log_prefix = "#{self.class.name}.doUpdate"
		begin
			$vim_log.info "#{log_prefix}: call to waitForUpdates...Starting" if $vim_log
			updateSet = waitForUpdates(@umPropCol, version)
			$vim_log.info "#{log_prefix}: call to waitForUpdates...Complete" if $vim_log
			version = updateSet.version

			return if updateSet.filterSet == nil || updateSet.filterSet.empty?
			
			updateSet.filterSet.each do |fu|
				next if fu.filter != @filterSpecRef
				fu.objectSet.each do |objUpdate|
					updateObject(objUpdate, &block)
				end
			end # updateSet.filterSet.each
			# Help out the Ruby Garbage Collector by resetting variables pointing to large objects back to nil
			updateSet = nil
			return version
		rescue HTTPClient::ReceiveTimeoutError => terr
			$vim_log.info "#{log_prefix}: call to waitForUpdates...Timeout" if $vim_log
			retry if isAlive?
			$vim_log.warn "#{log_prefix}: connection lost"
			raise terr
		end
	end
	
	def updateObject(objUpdate)
		log_prefix = "#{self.class.name}.updateObject"
		
        case objUpdate.kind
        when 'enter'
            yield(objUpdate.obj, propUpdate(objUpdate.changeSet))
        when 'leave'
            yield(objUpdate.obj, nil)
        when 'modify'
            yield(objUpdate.obj, propUpdate(objUpdate.changeSet))
        else
            $vim_log.warn "#{log_prefix}: unrecognized operation: #{objUpdate.kind}"
        end
    end
    
    def propUpdate(changeSet)
		changedProps = {}
        changeSet.each do |propChange|
            if @debugUpdates
                $vim_log.debug "\tpropChange name (path): #{propChange.name}"
                $vim_log.debug "\tpropChange op: #{propChange.op}"
                $vim_log.debug "\tpropChange val (type): #{propChange.val.class.to_s}"
            
                $vim_log.debug "\t*** propChange val START:"
                oGi = @globalIndent
                @globalIndent = "\t\t"
                dumpObj(propChange.val)
                @globalIndent = oGi
                $vim_log.debug "\t*** propChange val END"
                $vim_log.debug "\t***"
            end
          
			changedProps[propChange.name] = propChange.val
        end unless changeSet.nil?
		return changedProps
    end

	def stop
		log_prefix = "#{self.class.name}.stop"
		$vim_log.info "#{log_prefix}: stopping..."
		@monitor = false
		if @propCol
			$vim_log.info "#{log_prefix}: calling cancelWaitForUpdates"
			cancelWaitForUpdates(@propCol)
			$vim_log.info "#{log_prefix}: returned from cancelWaitForUpdates"
		end
	end

	def isAlive?
		return false if !@alive
		log_prefix = "#{self.class.name}.isAlive?"
	    begin
	        if !currentSession
				$vim_log.info "#{log_prefix}: Current session no longer exists."
				@alive = false
			end
        rescue Exception => err
			$vim_log.info "#{log_prefix}: Could not access connection - #{err.to_s}"
            @alive = false
        end
		return @alive
    end

	def currentSession
		return getMoProp(@sic.sessionManager, "currentSession")
	end
	
	def getMoProp(mo, path=nil)
		pfSpec = VimHash.new("PropertyFilterSpec") do |pfs|
			pfs.propSet	= VimArray.new("ArrayOfPropertySpec") do |psa|
				psa << VimHash.new("PropertySpec") do |ps|
					ps.type = mo.vimType
					if !path
					    ps.all = "true"
					else
					    ps.all = "false"
					    ps.pathSet = path
					end
				end
			end
			pfs.objectSet = VimArray.new("ArrayOfObjectSpec") do |osa|
				osa << VimHash.new("ObjectSpec") do |os|
					os.obj = mo
				end
			end
		end
		
		oca = retrieveProperties(@propCol, pfSpec)
		
		return nil if !oca || !oca[0] || !oca[0].propSet
		
		oc = oca[0]
		oc.delete('obj')
		
		oc.propSet = [oc.propSet] if !oc.propSet.kind_of?(Array)
	    oc.propSet.each do |ps|
	        #
	        # Here, ps.name can be a property path in the form: a.b.c
	        # If that's the case, we should set the target to: propHash['a']['b']['c']
	        # creating intermediate nodes as needed.
	        #
	        h, k = hashTarget(oc, ps.name)
	        if !h[k]
	            h[k] = ps.val
	        elsif h[k].kind_of? Array
	            h[k] << ps.val
	        else
				h[k] = VimArray.new do |arr|
					arr << h[k]
					arr << ps.val
				end
	        end
    	end # oc.propSet.each
		oc.delete('propSet')
		
		return(oc)
	end
	
	def hashTarget(baseHash, keyString, create=false)
	    return baseHash, keyString if !keyString.index('.')
	    
	    h = baseHash
	    ka = splitPropPath(keyString)
	    ka[0...-1].each do |k|
	        k, arrayKey = tagAndKey(k)
	        if arrayKey
	            array, idx = getVimArrayEnt(h[k], arrayKey, create)
	            raise "hashTarget: Could not traverse tree through array element #{k}[#{arrayKey}] in #{keyString}" if !array
	            h = array[idx]
            else
	            h[k] = VimHash.new if !h[k]
	            h = h[k]
            end
        end
        return h, ka[-1]
    end
    private :hashTarget
end
