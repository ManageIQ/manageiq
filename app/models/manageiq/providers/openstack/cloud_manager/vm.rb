class ManageIQ::Providers::Openstack::CloudManager::Vm < ManageIQ::Providers::CloudManager::Vm
  include_concern 'Operations'
  include_concern 'RemoteConsole'

  belongs_to :cloud_tenant

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

  def associate_floating_ip(public_network, port = nil)
    ext_management_system.with_provider_connection(:service => "Network",
                                                   :tenant_name => cloud_tenant.name) do |connection|
      unless port
        network_ports.each do |network_port|
          # Cycle through all ports and find one that is actually connected to the public network with router,
          if network_port.public_networks.detect { |x| x.try(:ems_ref) == public_network.ems_ref }
            port = network_port
            break
          end
        end
      end
      raise MiqException::MiqNetworkPortNotDefinedError, "Neutron port for floating IP association is not defined." unless port

      connection.create_floating_ip(public_network.ems_ref, :port_id => port.ems_ref)
    end
  end

  def delete_floating_ips(floating_ips)
    # TODO(lsmola) we have the method here because we need to take actual cloud_tenant from the VM.
    # This should be refactored to FloatingIP, when we can take tenant from elsewhere, Like user
    # session? They have it in session in Horizon, ehich correlates the teannt in keytsone token.
    ext_management_system.with_provider_connection(:service => "Network",
                                                   :tenant_name => cloud_tenant.name) do |connection|

      floating_ips.each do |floating_ip|
        connection.delete_floating_ip(floating_ip.ems_ref)
        # Destroy it also in CFME db, so we don't have to wait for refresh.
        floating_ip.destroy
      end
    end
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

  def validate_migrate
    validate_supported
  end

  def validate_smartstate_analysis
    validate_supported
  end
end
