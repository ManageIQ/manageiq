class MiqScvmmVm
  def initialize(invObj, vmh)
    unless invObj.nil?
      @invObj                 = invObj
      @vmService              = invObj.vmService
      @sic                    = invObj.sic
    end

    init(vmh)
	end # def initialize

	def init(vmh)
    #@vmService.stdout.puts "Init Hash for ScvmmVm [#{vmh.inspect}]"

    if vmh.empty?
      @props = {}
      return
    end

    @vmh                    = vmh.to_miq_a.first
    @props                  = @vmh[:Props]
    @name                   = @props[:Name]
    @uuid                   = @props[:VMId]
    @vmMor                  = @props[:VMId]
    @dsPath                 = @props[:VMCPath]
    @hostSystem             = @props[:HostName]
    @localPath              = @props[:VMCPath]

    @datacenterName         = nil
    @miqAlarmMor            = nil
    @snapshotInfo           = nil
		@cdSave					= nil
  end

  def start
    change_state(:start)
  end

  def stop
    change_state(:stop)
  end

  def shutdownGuest
    change_state(:shutdownGuest)
  end

  def suspend
    change_state(:suspend)
  end

  def pause
    change_state(:pause)
  end

  def change_state(newState)
    pso = @vmService.send(newState, @uuid)
    init(pso) unless pso.nil?
    return powerState
  end

	def powerState
    case @props[:StatusString].to_s.downcase
    when "running" then "on"
    when "paused"  then "paused"
    when "saved", "saved state" then "suspended"
    when "stopped", "poweroff"  then "off"
    when "missing", "incomplete vm configuration" then "unknown"
    else @props[:StatusString].to_s.downcase
    end
	end

	def poweredOn?
    powerState == "on"
	end

	def poweredOff?
    powerState == "off"
	end

	def suspended?
    powerState == "suspended"
	end

	def paused?
    powerState == "paused"
	end

	def connectionState
    true
	end

  def to_inv_h
    props = @props

    #uuid = UUIDHelper.clean_guid(props[:VMId])
    uid = props[:VMId].downcase
    name = props[:Name]
    vendor = 'microsoft'
    location = File.path_to_uri(props[:VMCPath], props[:HostName])
    tools_status = props[:VMAddition]
    connection_state = props[:Enabled]
    host_uid = props[:HostId]

    power_state = self.powerState()

    connection_state = false if power_state == "unknown"

    hardware = {}
    hardware[:numvcpus]= props[:CPUCount]
    hardware[:annotation] = props[:Description]
    hardware[:memory_cpu] = props[:Memory]
    hardware[:guest_os_full_name] = hardware[:guest_os] = "Other"
    hardware[:guest_devices] = self.guest_devices_inv_to_h

    result = {
      #:uid_ems => uid,
      :name => URI.decode(name),
      :uid_ems => uid,
      :vendor => vendor,
      :power_state => power_state,
      :location => location,
      :tools_status => tools_status,
      :connection_state => connection_state,

      # There really is no OS data here
      #:operating_system => os,
      :hardware => hardware,

      :snapshots => snapshots_to_inv_h,
      :host_uid => host_uid,      
    }

    return result
  end

  def snapshots_to_inv_h()
    spa = []
    props = @props
    props[:VMCheckpoints].to_miq_a.each do |snapshot|
      sp = snapshot[:Props]
      parent_uid = (props[:VMId] == sp[:ParentCheckpointID]) ? nil : sp[:ParentCheckpointID]
      current = sp == props[:LastRestoredVMCheckpoint]
      result = {
        :uid_ems=>sp[:CheckpointID],
        :current=>current,
        :create_time=>sp[:ModifiedTime].utc.iso8601(6),
        :description=>sp[:Description],
        :name=>sp[:Name],
        :uid=>sp[:CheckpointID],
        :parent_uid=>parent_uid
      }
      spa << result
    end
    return spa
  end

  def guest_devices_inv_to_h()
    props = @props
    all_nh = []
    props[:VirtualNetworkAdapters].to_miq_a.each do |a|
      device = a[:Props]
      all_nh << {
        :device_name => device[:VirtualNetworkAdapterType],
        :device_type => 'ethernet',
        :controller_type => 'ethernet',
        :present => device[:Enabled],
        :start_connected => device[:Enabled],
        :address => device[:EthernetAddress],
      }
    end
    return all_nh
  end
end
