class ManageIQ::Providers::Openstack::CloudManager::Vm < ManageIQ::Providers::CloudManager::Vm
  include_concern 'Operations'
  include_concern 'RemoteConsole'
  include_concern 'Resize'

  belongs_to :cloud_tenant

  has_many :cloud_networks, :through => :cloud_subnets
  alias_method :private_networks, :cloud_networks
  has_many :cloud_subnets, :through    => :network_ports,
                           :class_name => "ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet"
  has_many :public_networks, :through => :cloud_subnets
  has_many :security_groups, :through => :network_ports

  def floating_ip
    # Backwards compatibility layer with simplified architecture where VM has only one network
    floating_ips.first
  end

  def cloud_network
    # Backwards compatibility layer with simplified architecture where VM has only one network
    cloud_networks.first
  end

  def cloud_subnet
    # Backwards compatibility layer with simplified architecture where VM has only one network
    cloud_subnets.first
  end

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.servers.get(ems_ref)
  end

  def self.calculate_power_state(raw_power_state)
    case raw_power_state
    when "ACTIVE"                then "on"
    when "SHUTOFF"               then "off"
    when "SUSPENDED"             then "suspended"
    when "PAUSED"                then "paused"
    when "SHELVED"               then "shelved"
    when "SHELVED_OFFLOADED"     then "shelved_offloaded"
    when "REBOOT", "HARD_REBOOT" then "reboot_in_progress"
    when "ERROR"                 then "non_operational"
    when "BUILD", "REBUILD"      then "wait_for_launch"
    when "DELETED"               then "archived"
    when "MIGRATING"             then "migrating"
    else                              "unknown"
    end
  end

  def perform_metadata_scan(ost)
    require 'OpenStackExtract/MiqOpenStackVm/MiqOpenStackInstance'

    _log.debug "instance_id = #{ems_ref}"
    ost.scanTime = Time.now.utc unless ost.scanTime

    ems = ext_management_system
    os_handle = ems.openstack_handle

    begin
      miq_vm = MiqOpenStackInstance.new(ems_ref, os_handle)
      scan_via_miq_vm(miq_vm, ost)
    ensure
      miq_vm.unmount if miq_vm
    end
  end

  def perform_metadata_sync(ost)
    sync_stashed_metadata(ost)
  end

  def remove_evm_snapshot(snapshot_ci_id)
    # need vm_ci and os_id of snapshot
    unless (snapshot_ci = ::Snapshot.find_by(:id => snapshot_ci_id))
      _log.warn "snapshot with id #{snapshot_ci_id}, not found"
      return
    end

    raise "Could not find snapshot's VM" unless (vm_ci = snapshot_ci.vm_or_template)
    ext_management_system.vm_delete_evm_snapshot(vm_ci, snapshot_ci.ems_ref)
  end

  # TODO: Does this code need to be reimplemented?
  def proxies4job(_job)
    {
      :proxies => [MiqServer.my_server],
      :message => 'Perform SmartState Analysis on this Instance'
    }
  end

  def has_active_proxy?
    true
  end

  def has_proxy?
    true
  end

  def requires_storage_for_scan?
    false
  end

  def memory_mb_available?
    true
  end

  def validate_smartstate_analysis
    validate_supported_check("Smartstate Analysis")
  end
end
