class VmOpenstack < VmCloud
  include_concern 'Operations'
  include_concern 'RemoteConsole'

  belongs_to :cloud_tenant

  def provider_object(connection = nil)
    connection ||= self.ext_management_system.connect
    connection.servers.get(self.ems_ref)
  end

  def self.calculate_power_state(raw_power_state)
    case raw_power_state
    when "RUNNING"                                    then "on"
    when "BLOCKED", "PAUSED", "SUSPENDED", "BUILDING" then "suspended"
    when "SHUTDOWN", "SHUTOFF", "CRASHED", "FAILED"   then "off"
    else                                                   super
    end
  end

  def perform_metadata_scan(ost)
    require 'OpenStackExtract/MiqOpenStackVm/MiqOpenStackInstance'

    log_pref = "MIQ(#{self.class.name}##{__method__})"

    instance_id = ems_ref
    $log.debug "#{log_pref} instance_id = #{instance_id}"
    ost.scanTime = Time.now.utc unless ost.scanTime

    ems = ext_management_system
    os_handle = ems.openstack_handle

    begin
      miq_vm = MiqOpenStackInstance.new(instance_id, :openstack_handle => os_handle)
      scan_via_miq_vm(miq_vm, ost)
    ensure
      miq_vm.unmount if miq_vm
    end
  end

  def perform_metadata_sync(ost)
    sync_stashed_metadata(ost)
  end

  def remove_evm_snapshot(snapshot_ci_id)
    log_pref = "MIQ(#{self.class.name}##{__method__})"

    # need vm_ci and os_id of snapshot
    unless (snapshot_ci = ::Snapshot.where(:id => snapshot_ci_id).first)
      $log.warn "#{log_pref}: snapshot with id #{snapshot_ci_id}, not found"
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
end
