require 'manageiq'
require 'manageiq-loggers'
require 'miq_environment'

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

    def self.create_logger(log_file_name, logger_class = nil)
      if MiqEnvironment::Command.is_container?
        create_container_logger(log_file_name, logger_class)
      elsif MiqEnvironment::Command.supports_systemd?
        create_journald_logger(log_file_name, logger_class)
      else
        create_file_logger(log_file_name, logger_class)
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

    private_class_method def self.create_file_logger(log_file, logger_class)
      log_file = log_path_from_file(log_file)
      progname = progname_from_file(log_file)

      logger_class ||= ManageIQ::Loggers::Base
      logger_class.new(log_file, :progname => progname)
    end

    private_class_method def self.create_container_logger(log_file_name, logger_class)
      require "manageiq/loggers/container"
      logger = ManageIQ::Loggers::Container.new

      progname = progname_from_file(log_file_name)
      logger.progname = progname

      return logger if logger_class.nil?

      create_wrapper_logger(progname, logger_class, logger)
    end

    private_class_method def self.create_journald_logger(log_file_name, logger_class)
      require "manageiq/loggers/journald"
      logger = ManageIQ::Loggers::Journald.new

      progname = progname_from_file(log_file_name)
      logger.progname = progname

      return logger if logger_class.nil?

      create_wrapper_logger(progname, logger_class, logger)
    end

    private_class_method def self.log_path_from_file(log_file)
      log_file = Pathname.new(log_file) if log_file.kind_of?(String)
      log_file = ManageIQ.root.join("log", log_file) if log_file.try(:dirname).to_s == "."
      log_file
    end

    private_class_method def self.progname_from_file(log_file_name)
      log_file = Pathname.new(log_file) if log_file.kind_of?(String)
      log_file.try(:basename, ".*").to_s
    end

    private_class_method def self.create_wrapper_logger(progname, logger_class, wrapped_logger)
      logger_class.new(nil, :progname => progname).tap do |logger|
        logger.extend(ActiveSupport::Logger.broadcast(wrapped_logger))
      end
    end

    private_class_method def self.configure_external_loggers
      require 'awesome_spawn'
      AwesomeSpawn.logger = $log

      require 'inventory_refresh'
      InventoryRefresh.logger = $log
    end

    def self.apply_config_value(config, logger, key)
      old_level      = logger.level
      new_level_name = (config[key] || "INFO").to_s.upcase
      new_level      = Logger.const_get(new_level_name)
      if old_level != new_level
        $log.info("MIQ(#{name}.apply_config) Log level for #{logger.progname} has been changed to [#{new_level_name}]")
        logger.level = new_level
      end
    end

    def self.contents(log, last = 1000)
      log = log.instance_variable_get(:@logdev)&.filename.to_s if log.kind_of?(Logger)
      return "" unless File.file?(log)

      if last.nil?
        contents = File.readlines(log, :mode => "rb", :chomp => true)
      else
        require 'util/miq-system'
        contents = MiqSystem.tail(log, last)
      end
      return "" if contents.nil? || contents.empty?

      # Don't return lines containing invalid UTF8 byte sequences
      results = contents.select do |line|
        line&.unpack("U*") rescue nil
      end

      # Put back the utf-8 encoding which is the default for most rails libraries
      # after opening it as binary and getting rid of the invalid UTF8 byte sequences
      results.join("\n").force_encoding("utf-8")
    end
  end
end

Dir.glob(File.join(File.dirname(__FILE__), "loggers", "*")).each { |f| require f }
