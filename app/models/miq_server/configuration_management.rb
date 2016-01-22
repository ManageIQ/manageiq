module MiqServer::ConfigurationManagement
  extend ActiveSupport::Concern

  included do
    has_many :settings_changes, :as => :resource, :dependent => :destroy
  end

  def get_config(type = "vmdb")
    VMDB::Config.for_miq_server(self, type)
  end

  def set_config(config)
    config = config.config if config.respond_to?(:config)
    Vmdb::Settings.save!(self, config)
    settings_updated
  end

  def settings_updated
    if is_local?
      Vmdb::Settings.reload!
      Vmdb::Settings.activate
    elsif started?
      settings_updated_queue
    end
  end

  def settings_updated_queue
    MiqQueue.put(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "settings_updated",
      :priority    => MiqQueue::HIGH_PRIORITY,
      :zone        => nil,
      :role        => nil,
      :server_guid => guid
    )
  end

  # Callback from VMDB::Config::Activator#activate when the configuration has
  #   changed for this server
  def config_activated(data)
    # Check that the column exists in the table and we are passed data that does not match
    # the current vaule.  The first check allows this code to run if we migrate down then
    # back up again.
    if self.respond_to?(:name) && data.name && name != data.name
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
    @vmdb_config = VMDB::Config.new("vmdb")
    sync_log_level
    sync_worker_monitor_settings
    sync_child_worker_settings
    $log.log_hashes(@worker_monitor_settings)
  end

  def sync_config_changed?
    stale = @vmdb_config.stale?
    @vmdb_config = VMDB::Config.new("vmdb") if stale
    stale || @blacklisted_events.nil?
  end

  def sync_blacklisted_event_names
    @blacklisted_events = nil
  end

  def sync_log_level
    Vmdb::Loggers.apply_config(@vmdb_config.config[:log])
  end
end
