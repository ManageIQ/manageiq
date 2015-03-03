require 'sync'

require 'enumerator'
require "ostruct"

$:.push("#{File.dirname(__FILE__)}/../util")
$:.push("#{File.dirname(__FILE__)}/../util/extensions")
require 'miq-hash'
require 'miq-exception'
require 'MiqVimVdlMod'

class MiqVimVm

	include MiqVimVdlVcConnectionMod

    EVM_SNAPSHOT_NAME    = "EvmSnapshot"
    CH_SNAPSHOT_NAME     = /^Consolidate Helper/
    VCB_SNAPSHOT_NAME    = '_VCB-BACKUP_'
    NETAPP_SNAPSHOT_NAME = /^smvi/

    attr_reader :name, :localPath, :dsPath, :hostSystem, :uuid, :vmh, :devices, :invObj, :annotation, :customValues, :vmMor

    MIQ_ALARM_PFX = "MiqControl"

	def initialize(invObj, vmh)
	    @invObj                 = invObj
	    @sic                    = invObj.sic
		@cdSave					= nil
		@cfManager				= nil

	    init(vmh)

	    @miqAlarmSpecEnabled    = miqAlarmSpecEnabled
	    @miqAlarmSpecDisabled   = miqAlarmSpecDisabled

	    @cacheLock              = Sync.new
	end # def initialize

	def init(vmh)
	    @vmh                    = vmh
	    @name                   = vmh['summary']['config']['name']
	    @uuid                   = vmh['summary']['config']['uuid']
	    @vmMor                  = vmh['summary']['vm']
	    @dsPath                 = vmh['summary']['config']['vmPathName']
	    @hostSystem             = vmh['summary']['runtime']['host']
	    @devices                = vmh['config']['hardware']['device']		if vmh['config'] && vmh['config']['hardware']
	    @devices              ||= Array.new
		@annotation				= vmh['summary']['config']['annotation']	if vmh['summary']['config']
	    @localPath              = @invObj.localVmPath(@dsPath)
	    @miqAlarmName           = "#{MIQ_ALARM_PFX}-#{@uuid}"

		@customValues			= Hash.new
		if vmh['availableField'] && vmh['summary']['customValue']
			kton = Hash.new
			vmh['availableField'].each { |af| kton[af['key']] = af['name'] }
			vmh['summary']['customValue'].each { |cv| @customValues[kton[cv['key']]] = cv['value'] }
		end

	    @datacenterName         = nil
	    @miqAlarmMor            = nil
	    @snapshotInfo           = nil
    end

	def refresh
	     init(@invObj.refreshVirtualMachine(@vmMor))
    end

	#
	# Called when client is finished using this MiqVimVm object.
	# The server will delete its reference to the object, so the
	# server-side object csn be GC'd
	#
	def release
	    # @invObj.releaseObj(self)
    end

	def vmMor
	    return(@vmMor)
    end

    def vmh
        return(@vmh)
    end

	#######################
	# Power state methods.
	#######################

	def start(wait=true)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).start: calling powerOnVM_Task" if $vim_log
	    taskMor = @invObj.powerOnVM_Task(@vmMor)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).start: returned from powerOnVM_Task" if $vim_log
		return taskMor unless wait
	    waitForTask(taskMor)
	end # def start

	def stop(wait=true)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).stop: calling powerOffVM_Task" if $vim_log
	    taskMor = @invObj.powerOffVM_Task(@vmMor)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).stop: returned from powerOffVM_Task" if $vim_log
		return taskMor unless wait
	    waitForTask(taskMor)
	end # def stop

	def suspend(wait=true)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).suspend: calling suspendVM_Task" if $vim_log
	    taskMor = @invObj.suspendVM_Task(@vmMor)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).suspend: returned from suspendVM_Task" if $vim_log
		return taskMor unless wait
	    waitForTask(taskMor)
	end # def pause
	alias pause suspend

	def reset(wait=true)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).reset: calling resetVM_Task" if $vim_log
	    taskMor = @invObj.resetVM_Task(@vmMor)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).reset: returned from resetVM_Task" if $vim_log
		return taskMor unless wait
	    waitForTask(taskMor)
	end

	def rebootGuest
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).rebootGuest: calling rebootGuest" if $vim_log
	    @invObj.rebootGuest(@vmMor)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).rebootGuest: returned from rebootGuest" if $vim_log
    end

	def shutdownGuest
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).shutdownGuest: calling shutdownGuest" if $vim_log
	    @invObj.shutdownGuest(@vmMor)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).shutdownGuest: returned from shutdownGuest" if $vim_log
    end

    def standbyGuest
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).standbyGuest: calling standbyGuest" if $vim_log
        @invObj.standbyGuest(@vmMor)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).standbyGuest: returned from standbyGuest" if $vim_log
    end

	def powerState
	    getProp("runtime.powerState")["runtime"]["powerState"]
	end

	def poweredOn?
	    powerState == "poweredOn"
	end

	def poweredOff?
	    powerState == "poweredOff"
	end

	def suspended?
	    powerState == "suspended"
	end

	def connectionState
	    runtime = getProp("runtime.connectionState")
	    raise "Failed to retrieve property 'runtime.connectionState' for VM MOR: <#{@vmMor}>" if runtime.nil?
	    runtime["runtime"]["connectionState"]
	end

	############################
	# Template flag operations.
	############################

	def markAsTemplate
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).markAsTemplate: calling markAsTemplate" if $vim_log
	    @invObj.markAsTemplate(@vmMor)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).markAsTemplate: returned from markAsTemplate" if $vim_log
    end

    def markAsVm(pool, host=nil)
        hmor = nil
        hmor = (host.kind_of?(Hash) ? host['MOR'] : host) if host
	    pmor = (pool.kind_of?(Hash) ? pool['MOR'] : pool)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).markAsVm: calling markAsVirtualMachine" if $vim_log
        @invObj.markAsVirtualMachine(@vmMor, pmor, hmor)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).markAsVm: returned from markAsVirtualMachine" if $vim_log
    end

    def template?
        getProp("config.template")["config"]["template"] == "true"
    end

	################
	# VM Migration.
	################

	def migrate(host, pool=nil, priority="defaultPriority", state=nil)
	    hmor = (host.kind_of?(Hash) ? host['MOR'] : host)
	    pool = (pool.kind_of?(Hash) ? pool['MOR'] : pool) if pool

		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).migrate: calling migrateVM_Task, vm=<#{@vmMor.inspect}>, host=<#{hmor.inspect}>, pool=<#{pool.inspect}>, priority=<#{priority.inspect}>, state=<#{state.inspect}>" if $vim_log
	    taskMor = @invObj.migrateVM_Task(@vmMor, pool, hmor, priority, state)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).migrate: returned from migrateVM_Task" if $vim_log
	    $vim_log.debug "MiqVimVm::migrate: taskMor = #{taskMor}" if $vim_log
	    waitForTask(taskMor)
    end

	def relocateVM(host, pool=nil, datastore=nil, disk_move_type=nil, transform=nil, priority="defaultPriority", disk=nil)
		pmor  = (pool.kind_of?(Hash)      ? pool['MOR']      : pool)		if pool
		hmor  = (host.kind_of?(Hash)      ? host['MOR']      : host)		if host
		dsmor = (datastore.kind_of?(Hash) ? datastore['MOR'] : datastore)	if datastore

		rspec = VimHash.new('VirtualMachineRelocateSpec') do |rsl|
			rsl.datastore    = dsmor          if dsmor
			rsl.disk         = disk           if disk
			rsl.diskMoveType = disk_move_type if disk_move_type
			rsl.host         = hmor           if hmor
			rsl.pool         = pmor           if pmor
			rsl.transform    = transform      if transform
		end

		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).relocate: calling relocateVM_Task, vm=<#{@vmMor.inspect}>, host=<#{hmor.inspect}>, pool=<#{pool.inspect}>, datastore=<#{dsmor.inspect}>, priority=<#{priority.inspect}>" if $vim_log
		taskMor = @invObj.relocateVM_Task(@vmMor, rspec, priority)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).relocate: returned from relocateVM_Task" if $vim_log
		$vim_log.debug "MiqVimVm::relocate: taskMor = #{taskMor}" if $vim_log
		waitForTask(taskMor)
	end
	
	def cloneVM_raw(folder, name, spec, wait=true)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).cloneVM_raw: calling cloneVM_Task" if $vim_log
	    taskMor = @invObj.cloneVM_Task(@vmMor, folder, name, spec)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).cloneVM_raw: returned from cloneVM_Task" if $vim_log
	    $vim_log.debug "MiqVimVm::cloneVM_raw: taskMor = #{taskMor}" if $vim_log

		if wait
	    	rv = waitForTask(taskMor)
		    $vim_log.debug "MiqVimVm::cloneVM_raw: rv = #{rv}" if $vim_log
		    return rv
		end

		$vim_log.debug "MiqVimVm::cloneVM_raw - no wait: taskMor = #{taskMor}" if $vim_log
		return taskMor
	end

    def cloneVM(name, folder,
				pool=nil, host=nil, datastore=nil,
				powerOn=false, template=false, transform=nil,
				config=nil, customization=nil, disk=nil, wait=true)

        fmor  = (folder.kind_of?(Hash)    ? folder['MOR']    : folder)
        pmor  = (pool.kind_of?(Hash)      ? pool['MOR']      : pool)		if pool
        hmor  = (host.kind_of?(Hash)      ? host['MOR']      : host)		if host
	    dsmor = (datastore.kind_of?(Hash) ? datastore['MOR'] : datastore)	if datastore

	    cspec = VimHash.new('VirtualMachineCloneSpec') do |cs|
		    cs.powerOn          = powerOn.to_s
		    cs.template         = template.to_s
		    cs.config           = config		if config
		    cs.customization    = customization	if customization
	    	cs.location = VimHash.new('VirtualMachineRelocateSpec') do |csl|
				csl.datastore   = dsmor		if dsmor
				csl.host        = hmor		if hmor
				csl.pool        = pmor		if pmor
				csl.disk        = disk		if disk
				csl.transform   = transform	if transform
			end
		end
		cloneVM_raw(fmor, name, cspec, wait)
    end

	# def testCancel(tmor)
	# 	fault = VimHash.new('RequestCanceled') do |mf|
	# 		mf.faultMessage = VimHash.new('LocalizableMessage') do |lm|
	# 			lm.key = "EVM"
	# 			lm.message = "EVM test fault message"
	# 		end
	# 	end
	# 	@invObj.setTaskState(tmor, 'error', nil, fault)
	# 	# desc = VimHash.new('LocalizableMessage') do |lm|
	# 	# 		lm.key = "EVM"
	# 	# 		lm.message = "EVM test task description"
	# 	# end
	# 	# @invObj.setTaskDescription(tmor, desc)
	# end

    def unregister
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).unregister: calling unregisterVM" if $vim_log
        @invObj.unregisterVM(@vmMor)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).unregister: returned from unregisterVM" if $vim_log
    end

    def destroy
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).destroy: calling destroy_Task" if $vim_log
        taskMor = @invObj.destroy_Task(@vmMor)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).destroy: returned from destroy_Task" if $vim_log
        waitForTask(taskMor)
    end

	####################
	# Snapshot methods.
	####################

	def snapshotInfo_locked(refresh=false)
	    raise "snapshotInfo_locked: cache lock not held" if !@cacheLock.sync_locked?
	    return(@snapshotInfo) if @snapshotInfo && !refresh

	    begin
	        @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

    	    if !(ssp = @invObj.getMoProp_local(@vmMor, "snapshot"))
    	        @snapshotInfo = nil
    	        return(nil)
            end

    	    ssObj = ssp["snapshot"]
    	    ssMorHash = Hash.new
			rsl = ssObj['rootSnapshotList']
			rsl = [ rsl ] if !rsl.kind_of?(Array)
    	    rsl.each { |rs| @invObj.snapshotFixup(rs, ssMorHash) }
    	    ssObj['ssMorHash'] = ssMorHash
    	    @snapshotInfo = ssObj
	    ensure
	        @cacheLock.sync_unlock if unlock
        end

	    return(@snapshotInfo)
	end # def snapshotInfo_locked

	#
	# Public accessor
	#
	def snapshotInfo(refresh=false)
	    sni = nil
	    @cacheLock.synchronize(:SH) do
	        sni = @invObj.dupObj(snapshotInfo_locked)
        end
        return(sni)
    end

	def createEvmSnapshot(desc, quiesce="false", wait=true, free_space_percent=100)
		hasEvm    = hasSnapshot?(EVM_SNAPSHOT_NAME, true)
		hasCh     = hasSnapshot?(CH_SNAPSHOT_NAME, false)
		hasVcb    = hasSnapshot?(VCB_SNAPSHOT_NAME, false)
		hasNetApp = hasSnapshot?(NETAPP_SNAPSHOT_NAME, false)


		if hasEvm || hasCh || hasVcb
			raise MiqException::MiqVmSnapshotError, "VM has EVM and consolidate helper snapshots" if hasEvm && hasCh
			raise MiqException::MiqVmSnapshotError, "VM already has an EVM snapshot"              if hasEvm
			raise MiqException::MiqVmSnapshotError, "VM already has an VCB snapshot"              if hasVcb
			raise MiqException::MiqVmSnapshotError, "VM already has a NetApp snapshot"            if hasNetApp
			raise MiqException::MiqVmSnapshotError, "VM has a consolidate helper snapshot"
		end
		createSnapshot(EVM_SNAPSHOT_NAME, desc, false, quiesce, wait, free_space_percent)
	end

    def hasSnapshot?(name, refresh=false)
        @cacheLock.synchronize(:SH) do
            return false if !(si = snapshotInfo_locked(refresh))
            return !searchSsTree(si['rootSnapshotList'], 'name', name).nil?
        end
    end

	def searchSsTree(ssObj, key, value)
		ssObj = [ ssObj ] if !ssObj.kind_of?(Array)
		ssObj.each do |sso|
			if value.kind_of?(Regexp)
				return sso if value =~ sso[key]
			else
				return sso if sso[key] == value
			end
			sso['childSnapshotList'].each { |csso| s = searchSsTree(csso, key, value); return s unless s.nil? }
		end
		return nil
	end

	def createSnapshot(name, desc, memory, quiesce, wait=true, free_space_percent=100)
        $vim_log.debug "MiqVimVm::createSnapshot(#{name}, #{desc}, #{memory}, #{quiesce})" if $vim_log
		cs = connectionState
		raise "MiqVimVm(#{@invObj.server}, #{@invObj.username}).createSnapshot: VM is not connected, connectionState = #{cs}" if cs != "connected"
		snapshot_free_space_check('create', free_space_percent)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).createSnapshot: calling createSnapshot_Task" if $vim_log
	    taskMor = @invObj.createSnapshot_Task(@vmMor, name, desc, memory, quiesce)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).createSnapshot: returned from createSnapshot_Task" if $vim_log
	    $vim_log.debug "MiqVimVm::createSnapshot: taskMor = #{taskMor}" if $vim_log

		if wait
	    	snMor = waitForTask(taskMor)
		    $vim_log.debug "MiqVimVm::createSnapshot: snMor = #{snMor}" if $vim_log
		    return snMor
		end

		$vim_log.debug "MiqVimVm::createSnapshot - no wait: taskMor = #{taskMor}" if $vim_log
		return taskMor
	end # def createSnapshot

	def removeSnapshot(snMor, subTree="false", wait=true, free_space_percent=100)
	    $vim_log.debug "MiqVimVm::removeSnapshot(#{snMor}, #{subTree})" if $vim_log
	    snMor = getSnapMor(snMor)
		snapshot_free_space_check('remove', free_space_percent)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).removeSnapshot: calling removeSnapshot_Task" if $vim_log
	    taskMor = @invObj.removeSnapshot_Task(snMor, subTree)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).removeSnapshot: returned from removeSnapshot_Task" if $vim_log
	    $vim_log.debug "MiqVimVm::removeSnapshot: taskMor = #{taskMor}" if $vim_log
		return taskMor unless wait
	    waitForTask(taskMor)
	end # def removeSnapshot

	def removeSnapshotByDescription(description, refresh=false, subTree="false", wait=true, free_space_percent=100)
		mor = nil
	    @cacheLock.synchronize(:SH) do
			return false if !(si = snapshotInfo_locked(refresh))
			sso = searchSsTree(si['rootSnapshotList'], 'description', description)
			return false if sso.nil?
			mor = sso['snapshot']
	    end
		removeSnapshot(mor, subTree, wait, free_space_percent)
	    return true
	end # def removeSnapshotByDescription

	def removeAllSnapshots(free_space_percent=100)
        $vim_log.debug "MiqVimVm::removeAllSnapshots" if $vim_log
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).removeAllSnapshots: calling removeAllSnapshots_Task" if $vim_log
		snapshot_free_space_check('remove_all', free_space_percent)
	    taskMor = @invObj.removeAllSnapshots_Task(@vmMor)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).removeAllSnapshots: returned from removeAllSnapshots_Task" if $vim_log
	    $vim_log.debug "MiqVimVm::removeAllSnapshots: taskMor = #{taskMor}" if $vim_log
	    waitForTask(taskMor)
	end # def removeAllSnapshots

	def revertToSnapshot(snMor)
        $vim_log.debug "MiqVimVm::revertToSnapshot(#{snMor})" if $vim_log
	    snMor = getSnapMor(snMor)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).revertToSnapshot: calling revertToSnapshot_Task" if $vim_log
	    taskMor = @invObj.revertToSnapshot_Task(snMor)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).revertToSnapshot: returned from revertToSnapshot_Task" if $vim_log
	    $vim_log.debug "MiqVimVm::revertToSnapshot: taskMor = #{taskMor}" if $vim_log
	    waitForTask(taskMor)
	end # def revertToSnapshot

	def revertToCurrentSnapshot
	    $vim_log.debug "MiqVimVm::revertToCurrentSnapshot" if $vim_log
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).revertToCurrentSnapshot: calling revertToCurrentSnapshot_Task" if $vim_log
	    taskMor = @invObj.revertToCurrentSnapshot_Task(@vmMor)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).revertToCurrentSnapshot: returned from revertToCurrentSnapshot_Task" if $vim_log
	    $vim_log.debug "MiqVimVm::revertToCurrentSnapshot: taskMor = #{taskMor}" if $vim_log
	    waitForTask(taskMor)
	end # def revertToCurrentSnapshot

	def renameSnapshot(snMor, name, desc)
	    $vim_log.debug "MiqVimVm::renameSnapshot(#{snMor}, #{name}, #{desc})" if $vim_log
	    snMor = getSnapMor(snMor)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).renameSnapshot: calling renameSnapshot" if $vim_log
	    @invObj.renameSnapshot(snMor, name, desc)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).renameSnapshot: returned from renameSnapshot" if $vim_log
	end # def renameSnapshot

	def snapshot_free_space_check(action, free_space_percent=100)
		config = @invObj.getMoProp_local(@vmMor, "config")
		disk_space_per_datastore(@devices, snapshot_directory_mor(config)).each do |ds_mor, disk_space_in_kb|
			check_disk_space(action, ds_mor, disk_space_in_kb, free_space_percent)
		end
	end

	def check_disk_space(action, ds_mor, max_disk_space_in_kb, free_space_percent)
		pct = free_space_percent.to_f.zero? ? 100 : free_space_percent
		required_snapshot_space = ((max_disk_space_in_kb * 1024) * (pct.to_f/100.to_f)).to_i

		# Determine the free space on the datastore used for snapshots
		ds_summary    = @invObj.getMoProp_local(ds_mor, "summary")
		ds_name       = ds_summary.fetch_path('summary', 'name')
		ds_free_space = ds_summary.fetch_path('summary', 'freeSpace').to_i

		# Log results so we can reference if needed.
		if free_space_percent.to_f.zero?
			$log.info "Snapshot #{action} pre-check skipped for Datastore <#{ds_name}> due to Percentage:<#{free_space_percent}>.  Space Free:<#{ds_free_space}>  Disk size:<#{required_snapshot_space}>" if $log
			return
		end

		if ds_free_space < required_snapshot_space
			raise MiqException::MiqVmSnapshotError, "Snapshot #{action} aborted.  Datastore <#{ds_name}> does not have enough free space.  Space Free:<#{ds_free_space}>  Required:<#{required_snapshot_space}>  Disk Percentage Used:<#{free_space_percent}>"
		else
			$log.info "Snapshot #{action} pre-check OK.  Datastore <#{ds_name}> has enough free space.  Space Free:<#{ds_free_space}>  Required:<#{required_snapshot_space}>  Disk Percentage Used:<#{free_space_percent}>" if $log
		end
	end

	def disk_space_per_datastore(devices, snapshot_path_mor)
		# Add up the provision size of the disks.  Skip independent disk.
		devices.each_with_object(Hash.new {|h, k| h[k] = 0}) do |dev, hsh|
			next unless dev.xsiType == 'VirtualDisk'
			next if dev.fetch_path('backing', 'diskMode').to_s.include?('independent_')
			ds_mor = snapshot_path_mor ? snapshot_path_mor : dev.fetch_path('backing', 'datastore')
			hsh[ds_mor] += dev.capacityInKB.to_i
		end
	end

	def snapshot_directory_mor(config)
		if @invObj.apiVersion.to_i >= 5
			redoNotWithParent = config.fetch_path('config', 'extraConfig').detect {|ec| ec['key'] == 'snapshot.redoNotWithParent'}
			return nil if redoNotWithParent.nil? || redoNotWithParent['value'].to_s.downcase != "true"
		end
		snapshot_path = config.fetch_path('config', 'files', 'snapshotDirectory')
		dsn = @invObj.path2dsName(snapshot_path)
		@invObj.dsName2mo_local(dsn)
	end

	def getSnapMor(snMor)
	    if !snMor.respond_to?(:vimType)
	        $vim_log.debug "MiqVimVm::getSnapMor converting #{snMor} to MOR" if $vim_log
	        @cacheLock.synchronize(:SH) do
	            raise "getSnapMor: VM #{@dsPath} has no snapshots" if !(sni = snapshotInfo_locked(true))
    	        raise "getSnapMor: snapshot #{snMor} not found" if !(snObj = sni['ssMorHash'][snMor])
    	        snMor = snObj['snapshot']
	        end
	        $vim_log.debug "MiqVimVm::getSnapMor new MOR: #{snMor}" if $vim_log
	    end
	    return(snMor)
	end # def getSnapMor

	#########################
	# Configuration methods.
	#########################

	def getCfg(snap=nil)
		mor = snap ? getSnapMor(snap) : @vmMor
		cfgProps = @invObj.getMoProp(mor, "config")
		raise MiqException::MiqVimError, "Failed to retrieve configuration information for VM" if cfgProps.nil?
		cfgProps = cfgProps["config"]

		cfgHash = Hash.new
		cfgHash['displayname'] = cfgProps['name']
		cfgHash['guestos'] = cfgProps['guestId'].downcase.chomp("guest")
		cfgHash['uuid.bios'] = cfgProps['uuid']
		cfgHash['uuid.location'] = cfgProps['locationId']
		cfgHash['memsize'] = cfgProps['hardware']['memoryMB']
		cfgHash['numvcpu'] = cfgProps['hardware']['numCPU']
		cfgHash['config.version'] = cfgProps['version']

		controllerKeyHash = Hash.new

		1.upto(2) do |i|
			cfgProps['hardware']['device'].each do |dev|
				case dev.xsiType
				when 'VirtualIDEController'
					tag = "ide#{dev['busNumber']}"
					dev['tag'] = tag
					controllerKeyHash[dev['key']] = dev

				when 'VirtualLsiLogicController', 'VirtualLsiLogicSASController', 'ParaVirtualSCSIController'
					tag = "scsi#{dev['busNumber']}"
					dev['tag'] = tag
					controllerKeyHash[dev['key']] = dev
					cfgHash["#{tag}.present"] = "true"
					cfgHash["#{tag}.virtualdev"] = "lsilogic"

				when 'VirtualBusLogicController'
					tag = "scsi#{dev['busNumber']}"
					dev['tag'] = tag
					controllerKeyHash[dev['key']] = dev
					cfgHash["#{tag}.present"] = "true"
					cfgHash["#{tag}.virtualdev"] = "buslogic"

				when 'VirtualDisk'
					controller_tag = controllerKeyHash.fetch_path(dev['controllerKey'],'tag')
					next if controller_tag.nil?
					tag = "#{controller_tag}:#{dev['unitNumber']}"
					cfgHash["#{tag}.present"] = "true"
					cfgHash["#{tag}.devicetype"] = "disk"
					cfgHash["#{tag}.filename"] = dev['backing']['fileName']
					cfgHash["#{tag}.mode"] = dev['backing']['diskMode']
				when "VirtualCdrom"
					controller_tag = controllerKeyHash.fetch_path(dev['controllerKey'],'tag')
					next if controller_tag.nil?
					tag = "#{controller_tag}:#{dev['unitNumber']}"
					cfgHash["#{tag}.present"] = "true"
					if dev['backing']['fileName'].nil?
						cfgHash["#{tag}.devicetype"] = "cdrom-raw"
						cfgHash["#{tag}.filename"] = dev['backing']['deviceName']
					else
						cfgHash["#{tag}.devicetype"] = "cdrom-image"
						cfgHash["#{tag}.filename"] = dev['backing']['fileName']
					end
					cfgHash["#{tag}.startconnected"] = dev['connectable']['startConnected']
				when "VirtualFloppy"
					tag = "floppy#{dev['unitNumber']}"
					cfgHash["#{tag}.present"] = "true"
					if dev['backing']['fileName'].nil?
						cfgHash["#{tag}.filename"] = dev['backing']['deviceName']
					else
						cfgHash["#{tag}.filename"] = dev['backing']['fileName']
					end
					cfgHash["#{tag}.startconnected"] = dev['connectable']['startConnected']
				when "VirtualPCNet32", "VirtualE1000"
					tag = "ethernet#{dev['unitNumber'].to_i-1}"
					cfgHash["#{tag}.present"] = "true"
					cfgHash["#{tag}.networkname"] = dev['backing']['deviceName']
					cfgHash["#{tag}.generatedaddress"] = dev['macAddress']
					cfgHash["#{tag}.startconnected"] = dev['connectable']['startConnected']
					cfgHash["#{tag}.type"] = dev['deviceInfo']['label']
				else
					# Skip devices we don't care about.
					#$vim_log.warn "getCFG Skipped device: [#{dev.xsiType}]"
				end
			end
		end

		return cfgHash
	end # def getCfg

	def reconfig(vmConfigSpec)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).reconfig: calling reconfigVM_Task" if $vim_log
	    taskMor = @invObj.reconfigVM_Task(@vmMor, vmConfigSpec)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).reconfig: returned from reconfigVM_Task" if $vim_log
	    waitForTask(taskMor)
	end

    def getMemory
        getProp("summary.config.memorySizeMB")["summary"]["config"]["memorySizeMB"].to_i
    end

    def setMemory(memMB)
        vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") { |cs| cs.memoryMB = memMB }
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).setMemory: calling reconfigVM_Task" if $vim_log
	    taskMor = @invObj.reconfigVM_Task(@vmMor, vmConfigSpec)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).setMemory: returned from reconfigVM_Task" if $vim_log
	    waitForTask(taskMor)
    end

    def getNumCPUs
        getProp("summary.config.numCpu")["summary"]["config"]["numCpu"].to_i
    end

    def setNumCPUs(numCPUs)
		vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") { |cs| cs.numCPUs = numCPUs }
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).setNumCPUs: calling reconfigVM_Task" if $vim_log
	    taskMor = @invObj.reconfigVM_Task(@vmMor, vmConfigSpec)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).setNumCPUs: returned from reconfigVM_Task" if $vim_log
	    waitForTask(taskMor)
    end

    def devicesByFilter(filter)
        return(@invObj.applyFilter(@devices, filter))
    end

    def connectDevice(dev, connect=true, onStartup=false)
	    raise "connectDevice: device #{dev['deviceInfo']['label']} is not a removable device" if !@invObj.hasProp?(dev, "connectable")

	    vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") do |vmcs|
			vmcs.deviceChange = VimArray.new("ArrayOfVirtualDeviceConfigSpec") do |vmcs_vca|
				vmcs_vca << VimHash.new("VirtualDeviceConfigSpec") do |vdcs|
					vdcs.operation = VirtualDeviceConfigSpecOperation::Edit
					vdcs.device = @invObj.deepClone(dev)
					vdcs.device.connectable.startConnected = connect.to_s if onStartup
					vdcs.device.connectable.connected = connect.to_s
				end
			end
	    end

		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).connectDevice: calling reconfigVM_Task" if $vim_log
	    taskMor = @invObj.reconfigVM_Task(@vmMor, vmConfigSpec)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).connectDevice: returned from reconfigVM_Task" if $vim_log
	    waitForTask(taskMor)
	end # def connectDevice

	def attachIsoToCd(isoPath, cd=nil)
		raise "MiqVimVmMod.attachIsoToCd: CD already set" if @cdSave

		if !cd
			cd = devicesByFilter("deviceInfo.label" => "CD/DVD Drive 1")
			raise "MiqVimVmMod.attachIsoToCd: VM has no CD/DVD drive" if cd.empty?
			cd = cd.first
		end

		if (dsName = @invObj.path2dsName(isoPath)).empty?
			dsMor = nil
		else
			dsMor = @invObj.dsName2mo(dsName)
		end

		@cdSave	= @invObj.deepClone(cd)

		vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") do |vmcs|
			vmcs.deviceChange = VimArray.new("ArrayOfVirtualDeviceConfigSpec") do |vmcs_vca|
				vmcs_vca << VimHash.new("VirtualDeviceConfigSpec") do |vdcs|
					vdcs.operation = VirtualDeviceConfigSpecOperation::Edit
					vdcs.device = @invObj.deepClone(cd)
					vdcs.device.connectable.startConnected = "true"
					vdcs.device.connectable.connected = "true"
					vdcs.device.backing = VimHash.new("VirtualCdromIsoBackingInfo") do |vdb|
						vdb.fileName = isoPath
						vdb.datastore = dsMor if dsMor
					end
				end
			end
	    end

		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).attachIsoToCd: calling reconfigVM_Task" if $vim_log
	    taskMor = @invObj.reconfigVM_Task(@vmMor, vmConfigSpec)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).attachIsoToCd: returned from reconfigVM_Task" if $vim_log
	    waitForTask(taskMor)
	end

	def resetCd
		raise "MiqVimVmMod.resetCd: No previous CD state" if !@cdSave

		vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") do |vmcs|
			vmcs.deviceChange = VimArray.new("ArrayOfVirtualDeviceConfigSpec") do |vmcs_vca|
				vmcs_vca << VimHash.new("VirtualDeviceConfigSpec") do |vdcs|
					vdcs.operation = VirtualDeviceConfigSpecOperation::Edit
					vdcs.device = @cdSave
				end
			end
	    end

		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).resetCd: calling reconfigVM_Task" if $vim_log
	    taskMor = @invObj.reconfigVM_Task(@vmMor, vmConfigSpec)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).resetCd: returned from reconfigVM_Task" if $vim_log
	    waitForTask(taskMor)
	end

	#
	# Add a new SCSI disk to the VM.
	# Find an existing SCSI controller and add the disk to the next available unit number.
	#
	# If sizeInBM < 0, then assume the backing file already exists.
	#    In this case, backingFile must be the path to the existing VMDK.
	# If backingFile is just the datastore name, "[storage 1]" for example,
	#    file names will be generated as appropriate.
	#
	def addDisk(backingFile, sizeInMB, label=nil, summary=nil, thinProvisioned=false)
	    ck, un = getScsiCandU
	    raise "addDisk: no SCSI controller found" if !ck

		vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") do |vmcs|
			vmcs.deviceChange = VimArray.new("ArrayOfVirtualDeviceConfigSpec") do |vmcs_vca|
				vmcs_vca << VimHash.new("VirtualDeviceConfigSpec") do |vdcs|
					vdcs.operation = VirtualDeviceConfigSpecOperation::Add
					if sizeInMB < 0
				        sizeInMB = -sizeInMB
				    else
				        vdcs.fileOperation = VirtualDeviceConfigSpecFileOperation::Create
				    end
					vdcs.device = VimHash.new("VirtualDisk") do |vDev|
						vDev.key			= -100 # temp key for creation
					    vDev.capacityInKB	= sizeInMB * 1024
					    vDev.controllerKey	= ck
					    vDev.unitNumber		= un
					    # The following doesn't seem to work.
					    vDev.deviceInfo = VimHash.new("Description") do |desc|
							desc.label		= label
							desc.summary	= summary
						end if label || summary
						vDev.connectable = VimHash.new("VirtualDeviceConnectInfo") do |con|
							con.allowGuestControl	= "false"
						    con.startConnected		= "true"
						    con.connected			= "true"
						end
						vDev.backing = VimHash.new("VirtualDiskFlatVer2BackingInfo") do |bck|
							# bck.diskMode = VirtualDiskMode::Independent_nonpersistent
							bck.diskMode		= VirtualDiskMode::Independent_persistent
						    bck.split			= "false"
						    bck.thinProvisioned	= thinProvisioned.to_s
						    bck.writeThrough	= "false"
						    bck.fileName		= backingFile
							begin
						        dsn = @invObj.path2dsName(@dsPath)
						        bck.datastore = @invObj.dsName2mo_local(dsn)
						    rescue
						        bck.datastore = nil
						    end
						end
					end
				end
			end
	    end

		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).addDisk: calling reconfigVM_Task" if $vim_log
	    taskMor = @invObj.reconfigVM_Task(@vmMor, vmConfigSpec)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).addDisk: returned from reconfigVM_Task" if $vim_log
	    waitForTask(taskMor)
	end # def addDisk

	#
	# Remove the virtual disk device associated with the given backing file.
	# The backingFile must be the datastore path to the vmdk in question.
	# If deleteBacking is true, the backing file will be deleted, otherwise
	# the disk will be logically removed from the VM and the backing file
	# will remain in place.
	#
	def removeDiskByFile(backingFile, deleteBacking=false)
	    raise "removeDiskByFile: false setting for deleteBacking not yet supported" if deleteBacking == false
	    controllerKey, key = getDeviceKeysByBacking(backingFile)
	    raise "removeDiskByFile: no virtual device associated with: #{backingFile}" if !key
	    $vim_log.debug "MiqVimVm::MiqVimVm: backingFile = #{backingFile}" if $vim_log
	    $vim_log.debug "MiqVimVm::MiqVimVm: controllerKey = #{controllerKey}, key = #{key}" if $vim_log

		vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") do |vmcs|
			vmcs.deviceChange = VimArray.new("ArrayOfVirtualDeviceConfigSpec") do |vmcs_vca|
				vmcs_vca << VimHash.new("VirtualDeviceConfigSpec") do |vdcs|
					vdcs.operation = VirtualDeviceConfigSpecOperation::Remove
					if deleteBacking
				        vdcs.fileOperation = VirtualDeviceConfigSpecFileOperation::Destroy
				    else
				        vdcs.fileOperation = VirtualDeviceConfigSpecFileOperation::Replace
					end
					vdcs.device = VimHash.new("VirtualDisk") do |vDev|
						vDev.key			= key
					    vDev.capacityInKB	= 0
					    vDev.controllerKey	= controllerKey
						vDev.connectable = VimHash.new("VirtualDeviceConnectInfo") do |con|
							con.allowGuestControl	= "false"
						    con.startConnected		= "true"
						    con.connected			= "true"
						end
						vDev.backing = VimHash.new("VirtualDiskFlatVer2BackingInfo") do |bck|
							bck.diskMode		= VirtualDiskMode::Independent_persistent
						    bck.split			= "false"
						    bck.thinProvisioned	= "false"
						    bck.writeThrough	= "false"
						    bck.fileName		= backingFile
							begin
						        dsn = @invObj.path2dsName(@dsPath)
						        bck.datastore = @invObj.dsName2mo(dsn)
						    rescue
						        bck.datastore = nil
						    end
						end unless deleteBacking
					end
				end
			end
		end

		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).removeDiskByFile: calling reconfigVM_Task" if $vim_log
	    taskMor = @invObj.reconfigVM_Task(@vmMor, vmConfigSpec)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).removeDiskByFile: returned from reconfigVM_Task" if $vim_log
	    waitForTask(taskMor)
	end # def removeDiskByFile

	#
	# Find a SCSI controller and
	# return its key and next available unit number.
	#
	def getScsiCandU
	    devs = getProp("config.hardware")["config"]["hardware"]["device"]
	    ctrlrHash = Hash.new
	    devs.each do | dev |
            next if !(key = dev["key"])
            next if !dev["deviceInfo"]
            next if !(label = dev["deviceInfo"]["label"])
            ctrlrHash[key] = 0 if label =~ /^SCSI\s[Cc]ontroller\s.*$/
        end

        ctrlrHash.each_key do | ck |
            devs.each do | dev |
                next if !(controllerKey = dev["controllerKey"])
                next if controllerKey != ck
                next if !(unitNumber = dev["unitNumber"])
                unitNumber = unitNumber.to_i
                ctrlrHash[ck] = unitNumber if unitNumber > ctrlrHash[ck]
            end
        end

        ctrlrHash.each { | k, v | return([k, v + 1]) }
        return([nil, nil])
	end # def getScsiCandU

	#
	# Returns the [controllerKey, key] pair for the virtul device
	# associated with the given backing file.
	#
	def getDeviceKeysByBacking(backingFile)
	    devs = getProp("config.hardware")["config"]["hardware"]["device"]

	    devs.each do | dev |
            next if dev.xsiType != "VirtualDisk"
            next if dev["backing"]["fileName"] != backingFile
            return([dev["controllerKey"], dev["key"]])
        end
        return([nil, nil])
	end # def getDeviceKeysByBacking

	#####################
	# Miq Alarm methods.
	#####################

	#
	# Only called from initialize.
	#
	def miqAlarmSpecEnabled
	    VimHash.new("AlarmSpec") do |as|
		    as.name			= @miqAlarmName
		    as.description	= "#{MIQ_ALARM_PFX} alarm"
		    as.enabled		= "true"
			as.expression	= VimHash.new("StateAlarmExpression") do |sae|
			    sae.operator	= StateAlarmOperator::IsEqual
			    sae.statePath	= "runtime.powerState"
			    sae.type		= @vmMor.vimType
			    sae.yellow		= "poweredOn"
			    sae.red			= "suspended"
			end
			as.action = VimHash.new("AlarmTriggeringAction") do |aa|
			    aa.green2yellow = "true"
			    aa.yellow2red   = "false"
			    aa.red2yellow   = "true"
			    aa.yellow2green = "false"
			    aa.action		= VimHash.new("MethodAction") { |aaa| aaa.name = "SuspendVM_Task" }
			end
		end
	end
	private :miqAlarmSpecEnabled

	#
	# Only called from initialize.
	#
	def miqAlarmSpecDisabled
	    alarmSpec = @miqAlarmSpecEnabled.clone
	    alarmSpec.enabled = "false"
	    return(alarmSpec)
	end
	private :miqAlarmSpecEnabled

	#
	# If the alarm exists, return its MOR.
	# Otherwise, add the alarm and return its MOR.
	#
	def addMiqAlarm_locked
	    raise "addMiqAlarm_locked: cache lock not held" if !@cacheLock.sync_locked?
	    if (alarmMor = getMiqAlarm)
	        return(alarmMor)
	    end

	    begin
	        @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

    	    alarmManager = @sic.alarmManager
    	    #
    	    # Add disabled if VM is running.
    	    #
    	    if poweredOff?
    	        aSpec = @miqAlarmSpecEnabled
    	    else
    	        aSpec = @miqAlarmSpecDisabled
    	    end
			$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).addMiqAlarm_locked: calling createAlarm" if $vim_log
    	    alarmMor = @invObj.createAlarm(alarmManager, @vmMor, aSpec)
			$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).addMiqAlarm_locked: returned from createAlarm" if $vim_log
    	    @miqAlarmMor = alarmMor
    	ensure
	        @cacheLock.sync_unlock if unlock
        end

	    return(alarmMor)
	end # def addMiqAlarm_locked
	protected :addMiqAlarm_locked

	#
	# Public accessor
	#
	def addMiqAlarm
	    aMor = nil
	    @cacheLock.synchronize(:SH) do
	        aMor = addMiqAlarm_locked
        end
        return(aMor)
    end

	#
	# Return the MOR of the Miq alarm if it exists, nil otherwise.
	#
	def getMiqAlarm_locked
	    raise "addMiqAlarm_locked: cache lock not held" if !@cacheLock.sync_locked?
	    return(@miqAlarmMor) if @miqAlarmMor

	    begin
	        @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

			$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).getMiqAlarm_locked: calling getAlarm" if $vim_log
            alarms = @invObj.getAlarm(@sic.alarmManager, @vmMor)
			$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).getMiqAlarm_locked: returned from getAlarm" if $vim_log
            alarms.each do |aMor|
                ap = @invObj.getMoProp(aMor, "info.name")
                next if !ap['info']['name'][MIQ_ALARM_PFX]
                @miqAlarmMor = aMor
                return(aMor)
            end if alarms
        ensure
	        @cacheLock.sync_unlock if unlock
	    end

        return(nil)
	end # def getMiqAlarm_locked
	protected :getMiqAlarm_locked

	#
	# Public accessor
	#
	def getMiqAlarm
	    aMor = nil
	    @cacheLock.synchronize(:SH) do
	        aMor = getMiqAlarm_locked
        end
        return(aMor)
    end

	def disableMiqAlarm
	    @cacheLock.synchronize(:SH) do
	        raise "disableMiqAlarm: MiqAlarm not configured for VM #{@dsPath}" if (!aMor = getMiqAlarm_locked)
			$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).disableMiqAlarm: calling reconfigureAlarm" if $vim_log
    	    @invObj.reconfigureAlarm(aMor, @miqAlarmSpecDisabled)
			$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).disableMiqAlarm: returned from reconfigureAlarm" if $vim_log
	    end
	end

	def enableMiqAlarm
	    @cacheLock.synchronize(:SH) do
	        raise "enableMiqAlarm: MiqAlarm not configured for VM #{@dsPath}" if (!aMor = getMiqAlarm_locked)
			$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).enableMiqAlarm: calling reconfigureAlarm" if $vim_log
    	    @invObj.reconfigureAlarm(aMor, @miqAlarmSpecEnabled)
			$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).enableMiqAlarm: returned from reconfigureAlarm" if $vim_log
	    end
	end

	def removeMiqAlarm
	    @cacheLock.synchronize(:SH) do
	        return if (!aMor = getMiqAlarm_locked)
			$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).removeMiqAlarm: calling removeAlarm" if $vim_log
    	    @invObj.removeAlarm(aMor)
			$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).removeMiqAlarm: returned from removeAlarm" if $vim_log
    	    @miqAlarmMor = nil
	    end
	end

	def miqAlarmEnabled?
	    @cacheLock.synchronize(:SH) do
    	    return(false) if !(alarmMor = getMiqAlarm_locked)
    	    props = @invObj.getMoProp(alarmMor, "info.enabled")
    	    return(props['info.enabled'] == 'true')
	    end
	end

	###########################
	# extraConfig based methods
	###########################

	def extraConfig
		return @extraConfig unless @extraConfig.nil?

		@extraConfig = Hash.new
		vmh = getProp("config.extraConfig")
		if vmh['config'] && vmh['config']['extraConfig']
			vmh['config']['extraConfig'].each do |ov|
				# Fixes issue where blank values come back as VimHash objects
				value = ov['value'].kind_of?(VimHash) ? VimString.new("", nil, "xsd:string") : ov['value']
				@extraConfig[ov['key']] = value
			end
		end
		return @extraConfig
	end

	def getExtraConfigAttributes(attributes)
		rh = Hash.new
		attributes.each { |a| rh[a] = extraConfig[a] }
		return(rh)
	end

	def setExtraConfigAttributes(hash)
		raise "setExtraConfigAttributes: no attributes specified" if !hash.kind_of?(Hash) || hash.empty?

		vmConfigSpec = VimHash.new("VirtualMachineConfigSpec") do |vmcs|
			vmcs.extraConfig = VimArray.new("ArrayOfOptionValue") do |vmcs_eca|
				hash.each do |k, v|
					vmcs_eca << VimHash.new("OptionValue") do |ov|
						ov.key   = k.to_s
						ov.value = VimString.new(v.to_s, nil, "xsd:string")
					end
				end
			end
		end

		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).setExtraConfigAttributes: calling reconfigVM_Task" if $vim_log
		taskMor = @invObj.reconfigVM_Task(@vmMor, vmConfigSpec)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).setExtraConfigAttributes: returned from reconfigVM_Task" if $vim_log
		waitForTask(taskMor)

		@extraConfig = nil
		hash
	end

	def addExtraConfigPrefix(hash, prefix)
		hash.each_with_object({}) do |(k, v), rh|
			k = "#{prefix}.#{k}"
			rh[k] = v
		end
	end

	def removeExtraConfigPrefix(hash, prefix)
		hash.each_with_object({}) do |(k, v), rh|
			k = k[prefix.length + 1..-1]
			rh[k] = v
		end
	end

	#################
	# - vmSafe
	#################

	VmSafeAttributePrefix = 'vmsafe'
	VmSafeAttributes = [ 'vmsafe.enable', 'vmsafe.agentAddress', 'vmsafe.agentPort', 'vmsafe.failOpen', 'vmsafe.immutableVM', 'vmsafe.timeoutMS' ]

	def getVmSafeAttributes
		attrs = getExtraConfigAttributes(VmSafeAttributes)
		removeExtraConfigPrefix(attrs, VmSafeAttributePrefix)
	end

	def setVmSafeAttributes(hash)
		attrs = addExtraConfigPrefix(hash, VmSafeAttributePrefix)
		attrs.keys.each do |k|
			raise "setVmSafeAttributes: unrecognized attribute: #{k[VmSafeAttributePrefix.length + 1..-1]}" unless VmSafeAttributes.include?(k)
		end
		setExtraConfigAttributes(attrs)
	end

	def vmsafeEnabled?
		return false unless (ve = extraConfig['vmsafe.enable'])
		return ve.casecmp("true") == 0
	end

	####################
	# - remoteDisplayVnc
	####################

	RemoteDisplayVncAttributePrefix = 'RemoteDisplay.vnc'
	RemoteDisplayVncAttributes = [ 'RemoteDisplay.vnc.enabled', 'RemoteDisplay.vnc.key', 'RemoteDisplay.vnc.password', 'RemoteDisplay.vnc.port' ]

	def getRemoteDisplayVncAttributes
		attrs = getExtraConfigAttributes(RemoteDisplayVncAttributes)
		removeExtraConfigPrefix(attrs, RemoteDisplayVncAttributePrefix)
	end

	def setRemoteDisplayVncAttributes(hash)
		attrs = addExtraConfigPrefix(hash, RemoteDisplayVncAttributePrefix)
		attrs.each do |k, v|
			raise "setRemoteDisplayVncAttributes: unrecognized attribute: #{k[RemoteDisplayVncAttributePrefix.length + 1..-1]}" unless RemoteDisplayVncAttributes.include?(k)
			raise "setRemoteDisplayVncAttributes: RemoteDisplay.vnc.key cannot be set" if k == "RemoteDisplay.vnc.key"
			raise "setRemoteDisplayVncAttributes: RemoteDisplay.vnc.password cannot be longer than 8 characters" if k == "RemoteDisplay.vnc.password" && v.to_s.length > 8
		end
		setExtraConfigAttributes(attrs)
	end

	def remoteDisplayVncEnabled?
		return false unless (ve = extraConfig['RemoteDisplay.vnc.enabled'])
		return ve.casecmp("true") == 0
	end

	########################
	# Custom field methods.
	########################

	def cfManager
		@cfManager = @invObj.getMiqCustomFieldsManager if !@cfManager
		return @cfManager
	end

	def setCustomField(name, value)
		fk = cfManager.getFieldKey(name, @vmMor.vimType)
		cfManager.setField(@vmMor, fk, value)
	end

	###################
	# Utility Methods.
	###################

	def logUserEvent(msg)
	    @invObj.logUserEvent(@vmMor, msg)
	end

	def getProp(path=nil)
	    @invObj.getMoProp(@vmMor, path)
	end # def getProp

	def waitForTask(tmor)
	    @invObj.waitForTask(tmor, self.class.to_s)
    end

	def pollTask(tmor)
	    @invObj.pollTask(tmor, self.class.to_s)
    end

	def acquireMksTicket
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).acquireMksTicket: calling acquireMksTicket" if $vim_log
	    rv = @invObj.acquireMksTicket(@vmMor)
		$vim_log.info "MiqVimVm(#{@invObj.server}, #{@invObj.username}).acquireMksTicket: returned from acquireMksTicket" if $vim_log
	    return(rv)
	end # def acquireMksTicket

	def datacenterName
	    @cacheLock.synchronize(:SH) do
			@datacenterName = @invObj.vmDatacenterName(@vmMor) unless @datacenterName
			return @datacenterName
        end
    end
    private :datacenterName

    def vixVmxSpec
		#
		# For VDDK 1.1 and later, this is the preferred form for the vmxspec.
		#
		return "moref=#{@vmMor}"
		#
		# For pre 1.1 versions of VDDK, this vmxspec must be used.
		#
        # return "#{@invObj.dsRelativePath(@dsPath)}?dcPath=#{datacenterName}&dsName=#{@invObj.path2dsName(@dsPath)}"
    end

end # module MiqVimVmMod
