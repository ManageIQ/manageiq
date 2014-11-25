module MiqVimUpdate
	
	@@max_retries = 4
    
    def debugUpdates=(val)
        @debugUpdates = val
		@dumpToLog = true if @debugUpdates
    end

	def notifyMethod=(val)
		@notifyMethod = val
	end

	def updateDelay=(val)
        @updateDelay = val
    end

	def updateDelay
        @updateDelay
    end

	def monitorUpdatesInitial(preLoad)
		log_prefix = "MiqVimUpdate.monitorUpdatesInitial (#{@connId})"
		#
		# This timeout value setting for the session is serielized through the initialize method of DMiqVim.
		#
		ort = self.receiveTimeout
		self.receiveTimeout = 1200
		retries = @@max_retries
		begin
			$vim_log.info "#{log_prefix}: call to waitForUpdates...Starting" if $vim_log
			updateSet = waitForUpdates(@umPropCol)
			$vim_log.info "#{log_prefix}: call to waitForUpdates...Complete" if $vim_log
			version = updateSet.version

			if preLoad && @monitor
				@cacheLock.synchronize(:EX) do
					updateSet.filterSet.each do |fu|
						next if fu.filter != @filterSpecRef
						fu.objectSet.each { |objUpdate| updateObject(objUpdate, true) }
					end # updateSet.filterSet.each
					iUpdateFixUp
				end
			end
			# Help out the Ruby Garbage Collector by resetting variables pointing to large objects back to nil
			updateSet = nil
			return version
		rescue HTTPClient::ReceiveTimeoutError => terr
			$vim_log.info "#{log_prefix}: call to waitForUpdates...Timeout" if $vim_log
			raise terr if !isAlive? || retries <= 0
			retries -= 1
			self.receiveTimeout = self.receiveTimeout * 2
			$vim_log.info "#{log_prefix}: retrying - timeout: #{self.receiveTimeout}, retries remaining: #{retries}"
			retry
		ensure
			self.receiveTimeout = ort
		end
	end

	def monitorUpdatesSince(version)
		log_prefix = "MiqVimUpdate.monitorUpdatesSince (#{@connId})"
		begin
			$vim_log.info "#{log_prefix}: call to waitForUpdates...Starting (version = #{version})" if $vim_log
			updateSet = waitForUpdates(@umPropCol, version)
			$vim_log.info "#{log_prefix}: call to waitForUpdates...Complete (version = #{version})" if $vim_log
			version = updateSet.version

			return if updateSet.filterSet == nil || updateSet.filterSet.empty?

			updateSet.filterSet.each do |fu|
				next if fu.filter != @filterSpecRef
				fu.objectSet.each do |objUpdate|
                    $vim_log.info "#{log_prefix}: applying update...Starting (version = #{version})" if $vim_log
					@cacheLock.synchronize(:EX) do
						updateObject(objUpdate)
					end
                    $vim_log.info "#{log_prefix}: applying update...Complete (version = #{version})" if $vim_log
					Thread.pass
				end
			end # updateSet.filterSet.each
			# Help out the Ruby Garbage Collector by resetting variables pointing to large objects back to nil
			updateSet = nil
			return version
		rescue HTTPClient::ReceiveTimeoutError => terr
			$vim_log.info "#{log_prefix}: call to waitForUpdates...Timeout (version = #{version})" if $vim_log
			retry if isAlive?
			$vim_log.warn "#{log_prefix}: connection lost"
			raise terr
		end
	end

    def monitorUpdates(preLoad=false)
		log_prefix = "MiqVimUpdate.monitorUpdates (#{@connId})"
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

			version = monitorUpdatesInitial(preLoad)
			@updateMonitorReady = true

			while @monitor do
				updates_version = monitorUpdatesSince(version)
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
				$vim_log.error "******* #{herr.class}"
				$vim_log.error herr.to_s
				$vim_log.error herr.backtrace.join("\n") unless herr.kind_of?(HTTPClient::ReceiveTimeoutError) # already logged in monitorUpdatesInitial or monitorUpdatesSince
				raise herr
			end
		ensure
			if @filterSpecRef && isAlive?
				$vim_log.info "#{log_prefix}: calling destroyPropertyFilter...Starting"
				destroyPropertyFilter(@filterSpecRef)
				$vim_log.info "#{log_prefix}: calling destroyPropertyFilter...Complete"
			end
			@filterSpecRef = nil
			# @umPropCol     = nil
		end
	end # def monitorUpdates

	def stopUpdateMonitor
		log_prefix = "MiqVimUpdate.stopUpdateMonitor (#{@connId})"

		$vim_log.info "#{log_prefix}: for address=<#{@server}>, username=<#{@username}>...Starting"
		@monitor = false
		if @umPropCol
			if isAlive?
				$vim_log.info "#{log_prefix}: calling cancelWaitForUpdates...Starting"
				cancelWaitForUpdates(@umPropCol) 
				$vim_log.info "#{log_prefix}: calling cancelWaitForUpdates...Complete"
			end
			@umPropCol = nil
			@updateThread.run if @updateThread.status == "sleep"
		end
		$vim_log.info "#{log_prefix}: for address=<#{@server}>, username=<#{@username}>...Complete"
	end
	
	def forceFail
		isDead
		cancelWaitForUpdates(@umPropCol) if @umPropCol
	end
	
	def updateObject(objUpdate, initialUpdate=false)
		if !@inventoryHash # no cache to update
			return if !initialUpdate
			$vim_log.info "MiqVimUpdate.updateObject: setting @inventoryHash to empty hash"
			@inventoryHash = Hash.new
		end
        
        case objUpdate.kind
        when 'enter'
            addObject(objUpdate, initialUpdate)
        when 'leave'
            deleteObject(objUpdate, initialUpdate)
        when 'modify'
            updateProps(objUpdate, initialUpdate)
        else
            $vim_log.warn "MiqVimUpdate.updateObject (#{@connId}): unrecognized operation: #{objUpdate.kind}"
        end
    end
    
    def updateProps(objUpdate, initialUpdate=false)
        $vim_log.debug "Update object (#{@connId}): #{objUpdate.obj.vimType}: #{objUpdate.obj}" if @debugUpdates      
        return if !objUpdate.changeSet || objUpdate.changeSet.empty?
                
        #
        # Look up root hash of object in the <objType>ByMor hash and pass it
        # to the prop update routines: add, remove, assign.
        #
        objType = objUpdate.obj.vimType.to_sym
        if !(pm = @propMap[objType])
            # We don't cache this type of object
            return
        end
        hashName = "#{pm[:baseName]}ByMor"
        return if !(objHash = self.instance_variable_get(hashName)) # no cache to update
        if !(obj = objHash[objUpdate.obj])
            $vim_log.warn "updateProps (#{@connId}): object #{objUpdate.obj} not found in #{hashName}"
            return
        end
        
        begin
            #
            # Before updating the object's properties, save its initial key value.
            #
            keyPath		= pm[:keyPath]
			keyPath2	= pm[:keyPath2]
            key0		= keyPath ? eval("obj#{keyPath}") : nil
			key0b		= keyPath2 ? eval("obj#{keyPath2}") : nil

            changedProps = propUpdate(obj, objUpdate.changeSet, true)

            key1    	= keyPath ? eval("obj#{keyPath}") : nil
            
            #
            # If the property we use as a hash key has changed, re-hash the object.
            #
            if keyPath
                objHash = (key1 == key0) ? nil : self.instance_variable_get(pm[:baseName])
                unless objHash.nil?
					objHash.delete(key0)	if key0
					objHash.delete(key0b)	if key0b # changes when key0 changes.
					objHash[key1] = obj		if key1
					# Gets hashed by keyPath2 in objFixUp().
                end
            end

            #
            # Add our local values to cache:
            #   VMs:             ['summary']['config']['vmLocalPathName']
            #                    ['summary']["runtime"]["hostName"]
            #                    snapshot ['ssMorHash']
            #   Resource Pools:  ['summary']['name']
            #   
      		objFixUp(objType, obj)

            #
            # Call the notify callback if enabled, defined and we are past the initial update
            #
            if @notifyMethod && !initialUpdate
				$vim_log.debug "MiqVimUpdate.updateProps (#{@connId}): server = #{@server}, mor = (#{objUpdate.obj.vimType}, #{objUpdate.obj})"
				$vim_log.debug "MiqVimUpdate.updateProps (#{@connId}): changedProps = [ #{changedProps.join(', ')} ]"
      			Thread.new do
      				@notifyMethod.call(:server			=> @server,
              						   :username		=> @username,
              						   :op				=> 'update', 
              						   :objType			=> objUpdate.obj.vimType,
              						   :mor				=> objUpdate.obj,
              						   :changedProps	=> changedProps,
              						   :changeSet		=> objUpdate.changeSet,
              						   :key				=> key0,
              						   :newKey			=> key1
      				)
      			end
      		end
			
        rescue => err
            $vim_log.warn "MiqVimUpdate::updateProps (#{@connId}): #{err}"
            $vim_log.warn "Clearing cache for (#{@connId}): #{pm[:baseName]}"
            $vim_log.debug err.backtrace.join("\n")
            dumpCache("#{pm[:baseName]}ByMor")
            
            eval("#{pm[:baseName]}ByMor = nil")
            eval("#{pm[:baseName]} = nil")
        end
        
    end
    
    def addObject(objUpdate, initialUpdate)
        objType = objUpdate.obj.vimType
        # always log additions to the inventory.
        $vim_log.info "MiqVimUpdate.addObject (#{@connId}): #{objType}: #{objUpdate.obj}"
        return if !(pm = @propMap[objType.to_sym])  # not an object type we cache
        $vim_log.info "MiqVimUpdate.addObject (#{@connId}): Adding object #{objType}: #{objUpdate.obj}"
        
        #
        # First, add the object's MOR to the @inventoryHash entry for the object's type.
        #
        ia = @inventoryHash[objType] = Array.new if !(ia = @inventoryHash[objType])
        ia << objUpdate.obj if !ia.include? objUpdate.obj
        
        begin
            #
            # Then hash the object's properties in its type specific hash.
            #
            hashName = "#{pm[:baseName]}ByMor"
            if !self.instance_variable_get(hashName) # no cache to update
				return if !initialUpdate
				$vim_log.info "MiqVimUpdate.addObject: setting #{hashName} and #{pm[:baseName]} to empty hash"
				self.instance_variable_set(hashName, Hash.new)
				self.instance_variable_set(pm[:baseName], Hash.new)
			end
        
            obj = VimHash.new
            obj['MOR'] = objUpdate.obj
            propUpdate(obj, objUpdate.changeSet)
        
            addObjHash(objType.to_sym, obj)

            #
            # Call the notify callback if enabled, defined and we are past the initial update
            #
            if @notifyMethod && !initialUpdate
				$vim_log.debug "MiqVimUpdate.addObject: server = #{@server}, mor = (#{objUpdate.obj.vimType}, #{objUpdate.obj})"
                Thread.new do
                    @notifyMethod.call(:server   => @server,
                                       :username => @username,
                                       :op       => 'create',
                                       :objType  => objUpdate.obj.vimType,
                                       :mor      => objUpdate.obj
                    )
                end
            end

        rescue => err
            $vim_log.warn "MiqVimUpdate::addObject: #{err}"
            $vim_log.warn "Clearing cache for: #{pm[:baseName]}"
            $vim_log.debug err.backtrace.join("\n")
            dumpCache("#{pm[:baseName]}ByMor")
            
            eval("#{pm[:baseName]}ByMor = nil")
            eval("#{pm[:baseName]} = nil")
        end
    end
    
    def deleteObject(objUpdate, initialUpdate=false)
        objType = objUpdate.obj.vimType
        # always log deletions from the inventory.
        $vim_log.info "MiqVimUpdate.deleteObject (#{@connId}): #{objType}: #{objUpdate.obj}"
        return if !(pm = @propMap[objType.to_sym])      # not an object type we cache
        $vim_log.info "MiqVimUpdate.deleteObject (#{@connId}): Deleting object: #{objType}: #{objUpdate.obj}"
        
        ia = @inventoryHash[objType]
        ia.delete(objUpdate.obj)
        
        return if !self.instance_variable_get("#{pm[:baseName]}ByMor")  # no cache to update
        
        begin
            removeObjByMor(objUpdate.obj)

            #
            # Call the notify callback if enabled, defined and we are past the initial update
            #
            if @notifyMethod && !initialUpdate
				$vim_log.debug "MiqVimUpdate.deleteObject: server = #{@server}, mor = (#{objUpdate.obj.vimType}, #{objUpdate.obj})"
                Thread.new do
                    @notifyMethod.call(:server   => @server,
                                       :username => @username,
                                       :op       => 'delete',
                                       :objType  => objUpdate.obj.vimType,
                                       :mor      => objUpdate.obj
                    )
                end
            end

        rescue => err
            $vim_log.warn "MiqVimUpdate::deleteObject: #{err}"
            $vim_log.warn "Clearing cache for: #{pm[:baseName]}"
            $vim_log.debug err.backtrace.join("\n")
            dumpCache("#{pm[:baseName]}ByMor")
            
            eval("#{pm[:baseName]}ByMor = nil")
            eval("#{pm[:baseName]} = nil")
        end
    end
    
    def propUpdate(propHash, changeSet, returnChangedProps=false)
		changedProps = [] if returnChangedProps
        changeSet.each do |propChange|
            if @debugUpdates
                $vim_log.debug "\tpropChange name (path): #{propChange.name}"
                $vim_log.debug "\tpropChange op: #{propChange.op}"
                $vim_log.debug "\tpropChange val (type): #{propChange.val.class}"
            
                $vim_log.debug "\t*** propChange val START:"
                oGi = @globalIndent
                @globalIndent = "\t\t"
                dumpObj(propChange.val)
                @globalIndent = oGi
                $vim_log.debug "\t*** propChange val END"
                $vim_log.debug "\t***"
            end
            
            #
            # h is the parent hash of the property we're dealing with.
            # tag is the property name relative to the parent hash.
            # key identifies a specific array element, when the property is in an array.
            #
            h, propStr = hashTarget(propHash, propChange.name, true)
            tag, key   = tagAndKey(propStr)
            
            case propChange.op
            #
            # Add new entry into a collection (array)
            #
            when 'add'
                addToCollection(h, tag, propChange.val)
            #
            # Remove the property
            #
            when /remove|indirectRemove/
                if key
                    # The property is an element in an array
                    a, i = getVimArrayEnt(h[tag], key)
                    a.delete_at(i)
                else
                    h.delete(tag)
                end
            #
            # Assign a new value to the property
            #
            when 'assign'
                if key
                    # The property is an element in an array
                    a, i = getVimArrayEnt(h[tag], key, true)
                    a[i] = propChange.val
                else
                    h[tag] = propChange.val
                end
            end
			changedProps << propChange.name if returnChangedProps
        end
		return changedProps if returnChangedProps
    end
    
    def dumpCache(cache)
        return if !@debugUpdates
        $vim_log.debug "**** Dumping #{cache} cache"
        eval("dumpObj(#{cache})")
        $vim_log.debug "**** #{cache} dump end"
    end
    private :dumpCache

	def iUpdateFixUp
		@virtualMachinesByMor.each_value do |vm|
			if !vm['summary']['config']['vmLocalPathName']
				dsPath    = vm['summary']['config']['vmPathName']
	    	    localPath = localVmPath(dsPath)
				vm['summary']['config']['vmLocalPathName'] = localPath
				@virtualMachines[localPath] = vm if localPath
			end
		end if @virtualMachinesByMor
	end
	private :iUpdateFixUp
    
end # module MiqVimUpdate
