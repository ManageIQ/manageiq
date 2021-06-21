require 'manageiq'
require 'manageiq-loggers'
require 'miq_environment'
require 'util/vmdb-logger'

module Vmdb
  def self.logger
    $log
  end

  def self.rails_logger
    $rails_log
  end

  module Loggers
    def self.init
      return if @initialized
      create_loggers
      @initialized = true
    end

    def self.apply_config(config)
      apply_config_value(config, $log,                :level)
      apply_config_value(config, $audit_log,          :level_audit)
      apply_config_value(config, $rails_log,          :level_rails)
      apply_config_value(config, $policy_log,         :level_policy)
      apply_config_value(config, $remote_console_log, :level_remote_console)

      Vmdb::Plugins.each { |p| p.try(:apply_logger_config, config) }
    end

    def self.create_logger(log_file_name, logger_class = VMDBLogger)
      log_file = ManageIQ.root.join("log", log_file_name)
      progname = File.basename(log_file_name, ".*")

      logger_class.new(log_file, progname: progname).tap do |logger|
        broadcast_logger = create_broadcast_logger
        if broadcast_logger
          logger.extend(ActiveSupport::Logger.broadcast(broadcast_logger))
          broadcast_logger.progname = progname

          # HACK: In order to access the broadcast logger in test, we inject it
          #   as an instance var.
          logger.instance_variable_set(:@broadcast_logger, broadcast_logger) if Rails.env.test?
        end
      end
    end

    private_class_method def self.create_loggers
      $log                = create_logger("evm.log")
      $rails_log          = create_logger("#{Rails.env}.log")
      $audit_log          = create_logger("audit.log", AuditLogger)
      $policy_log         = create_logger("policy.log")
      $remote_console_log = create_logger("remote_console.log")

      configure_external_loggers
    end

    private_class_method def self.create_broadcast_logger
      create_container_logger || create_journald_logger
    end

    private_class_method def self.create_container_logger
      return unless ENV["CONTAINER"]

      require "manageiq/loggers/container"
      ManageIQ::Loggers::Container.new
    end

    private_class_method def self.create_journald_logger
      return unless MiqEnvironment::Command.supports_systemd?

      require "manageiq/loggers/journald"
      ManageIQ::Loggers::Journald.new
    rescue LoadError
      nil
    end

    private_class_method def self.configure_external_loggers
      require 'awesome_spawn'
      AwesomeSpawn.logger = $log

      require 'log_decorator'
      LogDecorator.logger = $log

      require 'inventory_refresh'
      InventoryRefresh.logger = $log
    end

    def self.apply_config_value(config, logger, key)
      old_level      = logger.level
      new_level_name = (config[key] || "INFO").to_s.upcase
      new_level      = VMDBLogger.const_get(new_level_name)
      if old_level != new_level
        $log.info("MIQ(#{name}.apply_config) Log level for #{File.basename(logger.filename)} has been changed to [#{new_level_name}]")
        logger.level = new_level
      end
    end
  end
end

require_relative "loggers/instrument"
Dir.glob(File.join(File.dirname(__FILE__), "loggers", "*")).each { |f| require f }
