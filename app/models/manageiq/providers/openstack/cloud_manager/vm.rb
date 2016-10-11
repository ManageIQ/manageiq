class ManageIQ::Providers::Openstack::CloudManager::Vm < ManageIQ::Providers::CloudManager::Vm
  include_concern 'Operations'
  include_concern 'RemoteConsole'
  include_concern 'Resize'
  include_concern 'AssociateIp'

  supports :smartstate_analysis do
    feature_supported, reason = check_feature_support('smartstate_analysis')
    unless feature_supported
      unsupported_reason_add(:smartstate_analysis, reason)
    end
  end

  POWER_STATES = {
    "ACTIVE"            => "on",
    "SHUTOFF"           => "off",
    "SUSPENDED"         => "suspended",
    "PAUSED"            => "paused",
    "SHELVED"           => "shelved",
    "SHELVED_OFFLOADED" => "shelved_offloaded",
    "HARD_REBOOT"       => "reboot_in_progress",
    "REBOOT"            => "reboot_in_progress",
    "ERROR"             => "non_operational",
    "BUILD"             => "wait_for_launch",
    "REBUILD"           => "wait_for_launch",
    "DELETED"           => "archived",
    "MIGRATING"         => "migrating",
  }.freeze

  alias_method :private_networks, :cloud_networks
  has_many :public_networks, :through => :cloud_subnets

  def floating_ip
    # TODO(lsmola) NetworkProvider Backwards compatibility layer with simplified architecture where VM has only one
    # network. Put this into ManageIQ::Providers::CloudManager::Vm when NetworkProvider is done in all providers
    floating_ips.first
  end

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.servers.get(ems_ref)
  end

  def self.calculate_power_state(raw_power_state)
    POWER_STATES[raw_power_state] || "unknown"
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

  def supports_snapshots?
    true
  end
end
