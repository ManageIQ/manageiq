module MiqServer::ConfigurationManagement
  extend ActiveSupport::Concern
  include ConfigurationManagementMixin

  def settings
    (is_local? ? ::Settings : settings_for_resource).to_hash
  end

  def reload_settings
    return if is_remote?

    Vmdb::Settings.reload!

    reset_server_caches
    notify_workers_of_config_change(Time.now.utc)
  end

  def servers_for_settings_reload
    [self]
  end

  # Callback from Vmdb::Settings::Activator#activate when the configuration has
  #   changed for this server
  def config_activated(data)
    # Check that the column exists in the table and we are passed data that does not match
    # the current vaule.  The first check allows this code to run if we migrate down then
    # back up again.
    if respond_to?(:name) && data.name && name != data.name
      self.name = data.name
    end

    unless data.zone.nil?
      zone = Zone.in_my_region.find_by(:name => data.zone)
      update(:zone => zone) if zone
    end

    save
  end

  def sync_config
    sync_worker_monitor_settings
    sync_child_worker_settings
    $log.log_hashes(@worker_monitor_settings)
  end

  def reset_server_caches
    sync_config
    sync_assigned_roles
    reset_queue_messages
  end
end
