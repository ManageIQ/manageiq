module MiqServer::ConfigurationManagement
  extend ActiveSupport::Concern

  included do
    has_many :settings_changes, :as => :resource, :dependent => :destroy
  end

  module ClassMethods
    def activate_configuration
      cfg = VMDB::Config.new("vmdb")
      cfg.activate

      up_to_date, *message = SchemaMigration.up_to_date?
      message.to_miq_a.each { |msg| _log.send(up_to_date ? :info : :warn, msg) }

      VMDB::Config.refresh_configs

      cfg
    end

    def config_updated
      cfg = VMDB::Config.new("vmdb")
      cfg.save
    end
  end

  def get_config(typ = "vmdb")
    config = nil

    if self.is_remote?
      record = configurations.find_by_typ(typ)
      if record
        config = VMDB::Config.new(typ, false)
        config.config = record.settings
      end
    end

    config || VMDB::Config.new(typ)
  end

  def set_config(cfg)
    unless cfg.kind_of?(VMDB::Config)
      raise _("Assertion Failure (MiqServer.set_config) -- config expected to be <VMDB::Config> but actually is <%{name}>") %
              {:name => cfg.class}
    end
    self.is_local? ? cfg.save : set_config_remote(cfg)
    reload
  end

  def set_config_remote(cfg)
    # Update the configuration
    Configuration.create_or_update(self, cfg.config, cfg.name)
    if cfg.name == "vmdb"
      # Update associated value in MiqServer
      unless cfg.config[:server].nil?
        ost = OpenStruct.new(cfg.config[:server].stringify_keys)
        config_updated(ost)
      end

      # Let the running server know that his config changed
      MiqQueue.put(
        :class_name  => "MiqServer",
        :method_name => "config_updated",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :zone        => nil,
        :role        => nil,
        :server_guid => guid
      ) if started?
    end
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
    if stale
      VMDB::Config.invalidate("vmdb")
      @vmdb_config = VMDB::Config.new("vmdb")
    end
    stale || @blacklisted_events.nil?
  end

  def sync_blacklisted_event_names
    @blacklisted_events = nil
  end
end
