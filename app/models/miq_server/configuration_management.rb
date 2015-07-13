module MiqServer::ConfigurationManagement
  extend ActiveSupport::Concern

  included do
    has_many :configurations, :dependent => :destroy
  end

  module ClassMethods
    def activate_configuration
      cfg = VMDB::Config.new("vmdb")
      cfg.activate

      up_to_date, *message = SchemaMigration.up_to_date?
      message.to_miq_a.each { |msg| _log.send(up_to_date ? :info : :warn, msg) }

      VMDB::Config.refresh_configs

      return cfg
    end
  end

  def get_config(typ = "vmdb", force_reload = false)
    VMDB::Config.invalidate(typ) if force_reload

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
    raise "Assertion Failure (MiqServer.set_config) -- config expected to be <VMDB::Config> but actually is <#{cfg.class}>" unless cfg.kind_of?(VMDB::Config)
    self.is_local? ? cfg.save : self.set_config_remote(cfg)
    self.reload
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
        :server_guid => self.guid
      ) if started?
    end
  end

  def sync_config
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
    stale
  end

end
