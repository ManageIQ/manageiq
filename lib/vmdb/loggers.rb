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

    def self.create_logger(log_file, logger_class = ManageIQ::Loggers::Base)
      log_file = Pathname.new(log_file) if log_file.kind_of?(String)
      log_file = ManageIQ.root.join("log", log_file) if log_file.try(:dirname).to_s == "."
      progname = log_file.try(:basename, ".*").to_s

      logger_class.new(log_file, :progname => progname).tap do |logger|
        ensure_log_file_permissions!(log_file)

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

    private_class_method def self.ensure_log_file_permissions!(log_file)
      return unless log_file.kind_of?(Pathname)
      return if !MiqEnvironment::Command.is_appliance? || MiqEnvironment::Command.is_podified?

      file_perm = 0o660 # Allow members of the manageiq group to write to log files
      file_uid  = MiqEnvironment.manageiq_uid
      file_gid  = MiqEnvironment.manageiq_gid

      stat = File.stat(log_file)

      File.chmod(file_perm, log_file)          unless stat.mode & file_perm == file_perm
      File.chown(file_uid, file_gid, log_file) unless stat.uid == file_uid && stat.gid == file_gid
    rescue Errno::EPERM
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
