module ManageIQ::Providers::Openstack::CloudManager::Vm::Operations::Relocation
  def raw_live_migrate(options = {})
    hostname         = options[:hostname]
    block_migration  = options[:block_migration]  || false
    disk_over_commit = options[:disk_over_commit] || false
    with_provider_connection do |connection|
      connection.live_migrate_server(ems_ref, hostname, block_migration, disk_over_commit)
    end
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:raw_power_state => "MIGRATING")
  end

  def live_migrate(options = {})
    raw_live_migrate(options)
  end

  def validate_live_migrate
    msg = validate_vm_control
    return {:available => msg[0], :message => msg[1]} unless msg.nil?
    return {:available => true,   :message => nil}
  end

  def validate_migrate
    validate_unsupported("Migrate")
  end
end
