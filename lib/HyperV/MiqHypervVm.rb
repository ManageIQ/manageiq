$:.push("#{File.dirname(__FILE__)}")
$:.push("#{File.dirname(__FILE__)}/../util")

require 'sync'
require 'miq-exception'
require 'timeout'

class MiqHypervVm
  VM_STATE =        {2=>"Running", 3=>"Stopped", 32768=>"Paused", 32769=>"Suspended", 32770=>"Starting",
    32771=>"Snapshotting",32773=>"Saving", 32774=>"Stopping" }
  BOOT_MEDIA =      {0=>"Floppy", 1=>"CD", 2=>"IDE", 3=>"NET" }
  STARTUP_ACTION =  {0=>"None" , 1=>"RestartOnly" , 2=>"AlwaysStartup"}
  SHUTDOWN_ACTION = {0=>"TurnOff", 1=>"SaveState", 2=>"ShutDown"}
  RECOVERY_ACTION = {0=>"None", 1=>"Restart", 2=>"RevertToSnapShot"}
  DISK_TYPE =       {2=>"Fixed", 3=>"Dynamic", 4=>"Differencing", 5=>"PhysicalDrive"}

  START = 2
  STOP  = 3
  SUSPEND = 32769
  PAUSE = 32768

  WMIDTD20 = 1

  EVM_SNAPSHOT_NAME = "EvmSnapshot"

	def initialize(invObj, vmh)
    @invObj                 = invObj
    init(vmh)
    @cacheLock              = Sync.new
	end # def initialize

	def init(vmh)
    @vmh                    = vmh
    @name                   = vmh[:display_name]
    @uuid                   = vmh[:uuid]
    @vmMor                  = vmh[:computer_system].Path_.Path
    #    @dsPath                 = vmh['summary']['config']['vmPathName']
    #    @hostSystem             = vmh['summary']['runtime']['hostName']
    #    @devices                = vmh['config']['hardware']['device'] if vmh['config'] && vmh['config']['hardware']
    #		@annotation				= vmh['config']['annotation']
    #    @devices                = Array.new if !devices
    #    @localPath              = @invObj.localVmPath(@dsPath)

    #		@extraConfig			= Hash.new
    #		vmh['config']['extraConfig'].each { |ov| @extraConfig[ov['key']] = ov['value'] }
  end

  def start
    requestStateChange(START)
  end

  def stop
    shutdown = shutdownGuest()
    requestStateChange(STOP) if shutdown == false
  end

  def suspend
    requestStateChange(SUSPEND)
  end

  def pause
    requestStateChange(PAUSE)
  end

	def reset(wait=true)
    requestStateChange(STOP)
    start
	end

  def shutdownGuest(msg='', force=true)
    shutdown_obj = @vmh.fetch_path(:runtime, :settings, :Msvm_ShutdownComponent)
    return false if shutdown_obj.blank?
    shutdown_obj = shutdown_obj.first
    $log.info "MiqHypervVm-shutdownGuest: Initiating VM shutdown"
    rc, targe, job = @invObj.shutdownGuest(shutdown_obj, msg, force)
    if rc.zero?
      self.wait_for_vm_shutdown
      current_state = @vmh[:computer_system].EnabledState.to_i
      if current_state == 2
        $log.info "MiqHypervVm-shutdownGuest: VM shutdown complete"
        return true
      else
        $log.info "MiqHypervVm-shutdownGuest: VM shutdown failed.  Current VM State: [#{current_state}]"
        return false
      end
    end
    $log.warn "MiqHypervVm-shutdownGuest: Job message:[#{@invObj.wmi_format_error(rc)}]  rc:[#{rc}]"
    return false if rc == 32768
    raise job.ErrorDescription unless job.nil?
    raise "MiqHyperVm-shutdownGuest: #{@invObj.wmi_format_error(rc)}"
  end

  def wait_for_vm_shutdown(timeout=30)
    @vmh[:computer_system].Refresh_
    current_state = @vmh[:computer_system].EnabledState.to_i
    # Check that the current state is valid for shutdown
    return unless [2,32774].include?(current_state)
    begin
      wait_for_vm_state_change(32774, timeout)
      # If we make it to the 'shutting down' state then we should get to the shutdown
      # state, but add a long (300 sec) timeout just in case.
      wait_for_vm_state_change(3, 300)
    rescue Timeout::Error
    end
  end

  def wait_for_vm_state_change(new_state, timeout)
    Timeout::timeout(timeout) do
      while @vmh[:computer_system].EnabledState.to_i != new_state do
        sleep(0.5)
        @vmh[:computer_system].Refresh_
      end
    end
  end
      
  def standbyGuest
    self.pause
  end

  def rebootGuest
    if self.shutdownGuest == true
      self.start
    end
  end

	def self.powerState(enabled_state)
		case enabled_state
		when 2, 32770, 32773 then "on"
		when 3, 32774        then "off"
		when 32769           then "suspended"
    when 32768           then "paused"
		else "unknown"
		end
	end

  def powerState
    self.class.powerState(@vmh[:computer_system].EnabledState.to_i)
  end

	def requestStateChange(state, wait=true)
    $log.info "MiqHypervVm-requestStateChange: Requesting state change to [#{state}]"
    rc, targe, job = @invObj.requestStateChange(@vmh[:computer_system] ,state, wait)
    return rc if rc.zero?
    raise job.ErrorDescription unless job.nil?
    raise "MiqHyperVm-requestStateChange: #{@invObj.wmi_format_error(rc)}  Current state:[#{@vmh[:computer_system].EnabledState}]  Requested state:[#{state}]"
	end

	def snapshotInfo_locked(refresh=false)
    raise "snapshotInfo_locked: cache lock not held" if !@cacheLock.sync_locked?
    return(@vmh[:snapshots][:list]) unless @vmh.fetch_path(:snapshots, :list).nil? || refresh

    begin
      @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)
      @vmh = @invObj.refresh_vm(@vmh[:computer_system])
    ensure
      @cacheLock.sync_unlock if unlock
    end

    return(@vmh[:snapshots][:list])
	end # def snapshotInfo_locked

  def refresh
    @cacheLock.synchronize(:SH) do
      snapshotInfo_locked(true)
    end
  end

	#
	# Public accessor
	#
	def snapshotInfo(refresh=false)
    sni = nil
    @cacheLock.synchronize(:SH) do
      sni = @invObj.dupObj(snapshotInfo_locked(refresh))
    end
    return(sni)
  end

  def currentSnaptshot
    @current_snapshot = @invObj.currentSnaptshot(@vmh[:computer_system])
  end

  def createEvmSnapshot(desc, quiesce="false", wait=true)
    hasEvm = hasSnapshot?(EVM_SNAPSHOT_NAME, true)
    raise MiqException::MiqVmSnapshotError, "VM already has an EVM snapshot" if hasEvm
    createSnapshot(EVM_SNAPSHOT_NAME, desc, false, quiesce, wait)
  end

  def hasSnapshot?(name, refresh=false)
    @cacheLock.synchronize(:SH) do
      return snapshotInfo_locked(refresh).any? {|s| s.ElementName == name}
    end
  end

  def getSnapGuid(guid, refresh=false)
    @cacheLock.synchronize(:SH) do
      return snapshotInfo_locked(refresh).detect {|s| s.InstanceID.include?(guid)}
    end
  end

  def createSnapshot(name, desc, memory=nil, quiesce=nil, wait=true)
    # Note: memory and quiesce flags are ignored, but included to maintain same method args as VMware
    waitForJob(@invObj.wmi_update_system('CreateVirtualSystemSnapshot', {'SourceSystem'=>@vmh[:computer_system].Path_.Path}), 'createSnapshot')
    sn = self.currentSnaptshot
    unless sn.nil?
      @invObj.renameSnapshot(@vmh[:computer_system], sn, name, desc)
       self.refresh
      return @vmh[:snapshots][:current]
    end
    return false
  end

	def removeSnapshot(snGuid, subTree="false", wait=true)
    sn = getSnapGuid(snGuid, true)
    unless sn.nil?
      method_name = subTree=="false" ? 'RemoveVirtualSystemSnapshot' : 'RemoveVirtualSystemSnapshotTree'
      waitForJob(@invObj.wmi_update_system(method_name, {'SnapshotSettingData'=>sn.Path_.Path}), 'removeSnapshot')
      self.refresh
    end
	end # def removeSnapshot

	def removeSnapshotByDescription(description, refresh=false, subTree="false")
		sn = nil
    @cacheLock.synchronize(:SH) do
			sn = snapshotInfo_locked(refresh).detect {|s| s.Notes == description}
			return false if sn.nil?
    end
		removeSnapshot(sn.InstanceID, subTree)
    return true
	end # def removeSnapshotByDescription

	def removeAllSnapshots
    @cacheLock.synchronize(:SH) do
      snapshotInfo_locked(true).each do |sn|
        if sn.Parent.nil?
          waitForJob(@invObj.wmi_update_system('RemoveVirtualSystemSnapshotTree', {'SnapshotSettingData'=>sn.Path_.Path}), 'removeAllSnapshots')
        end
      end
    end
    self.refresh
    return true
	end # def removeAllSnapshots

	def revertToSnapshot(snGuid)
    sn = getSnapGuid(snGuid)
    unless sn.nil?
      waitForJob(@invObj.applyVirtualSystemSnapshotEx(@vmh[:computer_system], sn), 'revertToSnapshot')
      return true
    end
    return false
	end # def revertToSnapshot

	def revertToCurrentSnapshot
    sn = self.currentSnaptshot
    unless sn.nil?
      waitForJob(@invObj.applyVirtualSystemSnapshotEx(@vmh[:computer_system], sn)[0], 'revertToCurrentSnapshot')
      return true
    end
    return false
	end # def revertToCurrentSnapshot

	def renameSnapshot(snGuid, name, desc)
    sn = getSnapGuid(snGuid)
    unless sn.nil?
      waitForJob(@invObj.renameSnapshot(@vmh[:computer_system], sn, name, desc), 'renameSnapshot')
      self.refresh
      return true
    end
    return false
	end # def renameSnapshot

  def getMemory
    @vmh.fetch_path([:config, :settings, :Msvm_MemorySettingData]).first.VirtualQuantity.to_i
  end

  def setMemory(memMB)
    mem = @vmh.fetch_path([:config, :settings, :Msvm_MemorySettingData]).first
    mem.Limit = mem.Reservation = mem.VirtualQuantity = memMB
    waitForJob(@invObj.wmi_update_system('ModifyVirtualSystemResources',
                                         {'ComputerSystem'=>@vmh[:computer_system].Path_.Path, 'ResourceSettingData'=>[mem.GetText_(WMIDTD20)]}), 'setMemory')
  end

  def getNumCPUs
    @vmh.fetch_path([:config, :settings, :Msvm_ProcessorSettingData]).first.VirtualQuantity.to_i
  end

  def setNumCPUs(numCPUs)
    vcpu = @vmh.fetch_path([:config, :settings, :Msvm_ProcessorSettingData]).first
    vcpu.VirtualQuantity = numCPUs
    waitForJob(@invObj.wmi_update_system('ModifyVirtualSystemResources',
                                         {'ComputerSystem'=>@vmh[:computer_system].Path_.Path, 'ResourceSettingData'=>[vcpu.GetText_(WMIDTD20)]}), 'setNumCPUs')
  end

  def waitForJob(job_rc, func_name)
    rc, targe, job = job_rc
    return rc if rc.zero?
    raise job.ErrorDescription unless job.nil?
    raise "MiqHyperVm-#{func_name}: #{@invObj.wmi_format_error(rc)}"
  end
end
