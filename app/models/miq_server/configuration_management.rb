module MiqServer::ConfigurationManagement
  extend ActiveSupport::Concern
  include ConfigurationManagementMixin

  def settings
    (is_local? ? ::Settings : settings_for_resource).to_hash
  end

  def reload_settings
    return if is_remote?

    Vmdb::Settings.reload!
    activate_settings_for_appliance
  end

  # The purpose of this method is to do special activation of things
  #   that can only happen once per server.  Normally, the
  #   Vmdb::Settings::Activator would be used, however the activations
  #   will end up occurring once per worker on the entire server, which
  #   can be detrimental.
  #
  #   As an example, ntp_reload works by telling systemctl to restart
  #   chronyd.  However, if this occurs on every worker, you end up with
  #   dozens of calls to `systemctl restart chronyd` simultaneously.
  #   Instead, this method will allow it to only happen once on
  #   the reload of settings in evmserverd.
  private def activate_settings_for_appliance
    ntp_reload_queue
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
      update_attributes(:zone => zone) if zone
    end
    update_capabilities

    save
  end

  def sync_config
    @blacklisted_events = true
    @config_last_loaded = Vmdb::Settings.last_loaded
    sync_log_level
    sync_worker_monitor_settings
    sync_child_worker_settings
    $log.log_hashes(@worker_monitor_settings)
  end

  def sync_config_changed?
    stale = @config_last_loaded != Vmdb::Settings.last_loaded
    @config_last_loaded = Vmdb::Settings.last_loaded if stale
    stale || @blacklisted_events.nil?
  end

  def sync_blacklisted_event_names
    @blacklisted_events = nil
  end

  def sync_log_level
    # TODO: Can this be removed since the Vmdb::Settings::Activator will do this anyway?
    Vmdb::Loggers.apply_config(::Settings.log)
  end
end
