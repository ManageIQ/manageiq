module ManageIQ::Providers::Openstack::CloudManager::Vm::Operations::Relocation
  extend ActiveSupport::Concern

  included do
    supports :live_migrate do
      unsupported_reason_add(:live_migrate, unsupported_reason(:control)) unless supports_control?
    end

    supports_not :migrate, :reason => _("Migrate operation is not supported.")

    supports :evacuate do
      unsupported_reason_add(:evacuate, unsupported_reason(:control)) unless supports_control?
    end
  end

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

  def raw_evacuate(options = {})
    hostname          = options[:hostname]
    on_shared_storage = options[:on_shared_storage]
    # on_shared_storage is required, by default we have Ceph shared storage, so set it to true
    on_shared_storage = true if on_shared_storage.nil?
    admin_password    = options[:admin_password]
    with_provider_connection do |connection|
      connection.evacuate_server(ems_ref, hostname, on_shared_storage, admin_password)
    end
    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:raw_power_state => "MIGRATING")
  end
end
