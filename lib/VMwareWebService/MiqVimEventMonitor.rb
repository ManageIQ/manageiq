require 'enumerator'
require 'MiqVimInventory'

class MiqVimEventMonitor < MiqVimInventory
	
    def initialize(server, username, password, eventFilterSpec=nil, pgSize=100)
        super(server, username, password, :cache_scope_event_monitor)
        
	    @eventFilterSpec = eventFilterSpec || VimHash.new("EventFilterSpec")
	    @pgSize = pgSize
		@_monitorEvents = true
		@emPropCol = nil
	    
	    hostSystemsByMor
		# datacentersByMor
		virtualMachinesByMor
		# dataStoresByMor
	end # def initialize
    
    def monitorEvents
        raise "monitorEvents: no block given" if !block_given?

		trap(:TERM) { $vim_log.info "monitorEvents: ignoring SIGTERM" }
                
		eventHistoryCollector = createCollectorForEvents(@sic.eventManager, @eventFilterSpec)
		setCollectorPageSize(eventHistoryCollector, @pgSize)
		
		pfSpec = VimHash.new("PropertyFilterSpec") do |pfs|
			pfs.propSet	= VimArray.new("ArrayOfPropertySpec") do |psa|
				psa << VimHash.new("PropertySpec") do |ps|
					ps.type = eventHistoryCollector.vimType
				    ps.all = "false"
				    ps.pathSet = "latestPage"
				end
			end
			pfs.objectSet = VimArray.new("ArrayOfObjectSpec") do |osa|
				osa << VimHash.new("ObjectSpec") do |os|
					os.obj = eventHistoryCollector
				end
			end
		end
		
		filterSpecRef = nil
		
		begin
    		@emPropCol = @sic.propertyCollector
    		filterSpecRef = createFilter(@emPropCol, pfSpec, "true")
		
			version = nil
    		begin
    		    while @_monitorEvents do
        		    updateSet = waitForUpdates(@emPropCol, version)
        		    version = updateSet.version
		    
        		    next if updateSet.filterSet == nil || updateSet.filterSet.empty?
    		        fu = updateSet.filterSet[0]
    		        next if fu.filter != filterSpecRef
    	            objUpdate = fu.objectSet[0]
    	            next if objUpdate.kind != ObjectUpdateKind::Modify
    	            next if objUpdate.changeSet.empty?
	            
    	            changeSetAry = Array.new
                    objUpdate.changeSet.each do |propChange|
                        next unless propChange.name =~ /latestPage.*/
                        next if !propChange.val
						if propChange.val.kind_of?(Array)
							propChange.val.each { |v| changeSetAry << fixupEvent(v) }
						else
                        	changeSetAry << fixupEvent(propChange.val)
						end
                    end
                    yield changeSetAry
        		end
        	rescue HTTPClient::ReceiveTimeoutError => terr
    	        retry if isAlive?
    	        $vim_log.debug "MiqVimEventMonitor.monitorEvents: connection lost"
    	        raise
	        end
    	rescue SignalException => err
    	ensure
			$vim_log.info "MiqVimEventMonitor: calling destroyPropertyFilter"
	    	destroyPropertyFilter(filterSpecRef) if filterSpecRef
			$vim_log.info "MiqVimEventMonitor: returned from destroyPropertyFilter"
			disconnect
    	end
	end # def monitorEvents
	
	def stop
		$vim_log.info "MiqVimEventMonitor stopping..."
		@_monitorEvents = false
		if @emPropCol
			$vim_log.info "MiqVimEventMonitor: calling cancelWaitForUpdates"
			cancelWaitForUpdates(@emPropCol)
			$vim_log.info "MiqVimEventMonitor: returned from cancelWaitForUpdates"
		end
	end
		
	# The set of events for which fixupEvent should add a VM
    ADD_VM_EVENTS = ['VmCreatedEvent', 'VmClonedEvent', 'VmDeployedEvent', 'VmRegisteredEvent']

	def fixupEvent(event)
		unless event.kind_of?(Hash)
			$vim_log.error "MiqVimEventMonitor.fixupEvent: Expecting Hash, got #{event.class}"
			if event.kind_of?(Array)
				event.each_index do |i|
					$vim_log.error "MiqVimEventMonitor.fixupEvent: event[#{i}] is a #{event[i].class}"
					$vim_log.error "\tMiqVimEventMonitor.fixupEvent: event[#{i}] = #{event[i].inspect}"
				end
			else
				$vim_log.error "\tMiqVimEventMonitor.fixupEvent: event = #{event.inspect}"
			end
			raise "MiqVimEventMonitor.fixupEvent: Expecting Hash, got #{event.class}"
		end
		
		event['eventType'] = event.xsiType.split("::").last
	    @cacheLock.synchronize(:SH) do
    	    ['vm', 'sourceVm', 'srcTemplate'].each do |vmStr|
    	        next if !(eventVmObj = event[vmStr])
    	        addVirtualMachine(eventVmObj['vm']) if ADD_VM_EVENTS.include?(event['eventType'])
    	        next if !(vmObj = virtualMachinesByMor_locked[eventVmObj['vm']])
    	        eventVmObj['path'] = vmObj['summary']['config']['vmPathName']
    	        removeVirtualMachine(eventVmObj['vm']) if event['eventType'] == 'VmRemovedEvent'
    	    end
	    end
		et = event['eventType']
		if et == 'VmRelocatedEvent' || et == 'VmMigratedEvent' || et == 'DrsVmMigratedEvent' || et == 'VmResourcePoolMovedEvent' ||
		   (et == 'TaskEvent' && event['info']['name'] == 'MarkAsVirtualMachine')
			vmMor = event['vm']['vm']
			removeVirtualMachine(vmMor)
			addVirtualMachine(vmMor)
		end
	    return(event)
	end
	
	def monitorEventsToStdout
	    monitorEvents do |ea|
	        ea.each do |e|
    	        puts
    	        puts "*** New Event: #{e['eventType']}"
                dumpObj(e)
				# doEvent(e)
            end
	    end
	end
	
	def monitorEventsTest
	    monitorEvents do |ea|
	        ea.each do |e|
                puts e['message'] if e['message']
            end
	    end
	end
	
	#
	# Test: prevent clone of VM: rpo-clone-src
	#
	def doEvent(e)
		return if e['eventType'] != "TaskEvent"
		return if e['info']['name'] != "CloneVM_Task"
		return if e['vm']['name'] != "rpo-clone-src"
		begin
			cancelTask(String.new(e['info']['task'].to_str))
		rescue => err
			$vim_log.error err.to_s
			$vim_log.error err.backtrace.join("\n")
		end
	end
end # module MiqVimEventMonitor
