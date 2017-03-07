module MiqServer::ConfigurationManagement
  extend ActiveSupport::Concern
  include ConfigurationManagementMixin

  def get_config(type = "vmdb")
    if is_local?
      VMDB::Config.new(type)
    else
      VMDB::Config.for_resource(type, self)
    end
  end

  def set_config(config)
    config = config.config if config.respond_to?(:config)
    add_settings_for_resource(config)
    ntp_reload_queue
  end

  def reload_settings
    Vmdb::Settings.reload! if is_local?
  end

  def servers_for_settings_reload
    [self]
  end

  # Callback from VMDB::Config::Activator#activate when the configuration has
  #   changed for this server
  def config_activated(data)
    # Check that the column exists in the table and we are passed data that does not match
    # the current vaule.  The first check allows this code to run if we migrate down then
    # back up again.
    if respond_to?(:name) && data.name && name != data.name
      self.name = data.name
    end

    unless data.zone.nil?
      self.zone = Zone.in_my_region.find_by(:name => data.zone)
      save
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
    # TODO: Can this be removed since the VMDB::Config::Activator will do this anyway?
    Vmdb::Loggers.apply_config(::Settings.log)
  end
end
