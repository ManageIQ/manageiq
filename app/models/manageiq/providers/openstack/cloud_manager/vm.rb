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

  def associate_floating_ip_from_network(public_network, port = nil)
    ext_management_system.with_provider_connection(:service     => "Network",
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
      unless port
        raise(MiqException::MiqNetworkPortNotDefinedError,
              "Neutron port for floating IP association is not defined for OpenStack"\
              "network #{public_network.ems_ref} and EMS '#{ext_management_system.name}'")
      end

      connection.create_floating_ip(public_network.ems_ref, :port_id => port.ems_ref)
    end
  end

  def delete_floating_ips(floating_ips)
    # TODO(lsmola) we have the method here because we need to take actual cloud_tenant from the VM.
    # This should be refactored to FloatingIP, when we can take tenant from elsewhere, Like user
    # session? They have it in session in Horizon, ehich correlates the teannt in keytsone token.
    ext_management_system.with_provider_connection(:service     => "Network",
                                                   :tenant_name => cloud_tenant.name) do |connection|
      floating_ips.each do |floating_ip|
        begin
          connection.delete_floating_ip(floating_ip.ems_ref)
        rescue StandardError => e
          # The FloatingIp could have been deleted by another process
          _log.info("Could not delete floating IP #{floating_ip} in EMS "\
                    "'#{ext_management_system.name}'. Error: #{e}")
        end
        # Destroy it also in db, so we don't have to wait for refresh.
        floating_ip.destroy
      end
    end
  end

  def destroy_if_failed
    if raw_power_state.downcase.to_sym == :error
      provider_object.destroy
      destroy
    end
  end

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.servers.get(ems_ref)
  end

  def with_provider_object
    super(connection_options)
  end

  def with_provider_connection
    super(connection_options)
  end

  def self.connection_options(cloud_tenant = nil)
    connection_options = { :service => 'Compute' }
    connection_options[:tenant_name] = cloud_tenant.name if cloud_tenant
    connection_options
  end

  def connection_options
    self.class.connection_options(cloud_tenant)
  end
  private :connection_options

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
