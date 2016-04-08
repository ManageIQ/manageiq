module MiqServer::ConfigurationManagement
  extend ActiveSupport::Concern

  included do
    has_many :settings_changes, :as => :resource, :dependent => :destroy
  end

  def get_config(type = "vmdb")
    VMDB::Config.for_resource(type, self)
  end

  def set_config(config)
    config = config.config if config.respond_to?(:config)
    Vmdb::Settings.save!(self, config)

    # Reload the settings immediately for this worker. This is typically a UI
    #   worker making the change, who will need to see the changes right away.
    reload_settings
    # Reload the settings for all workers on the server whether local or remote.
    enqueue_for_server('reload_settings') if started?
  end

  def reload_settings
    Vmdb::Settings.reload! if is_local?
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
      self.zone = Zone.find_by(:name => data.zone)
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
