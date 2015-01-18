require 'vmdb-logger'
require 'vmdb_helper'  # TODO: eventually replace this with requiring Vmdb::Config directly

Dir.glob(File.join(File.dirname(__FILE__), "logging", "*")).each { |f| require f }

module Vmdb
  def self.logger
    $log
  end

  def self.rails_logger
    $rails_log
  end

  module Logging
    DEFAULT_LOG_LEVEL = "INFO"
    DEFAULT_LOG_PATH  = Rails.root.join("log", "#{Rails.env}.log")
    DEFAULT_LOG_DIR   = File.dirname(DEFAULT_LOG_PATH)

    LEVEL_CONFIG_KEYS = [
      :level,
      :level_rails,
      :level_vim,
      :level_vim_in_evm,
      :level_rhevm,
      :level_rhevm_in_evm,
      :level_aws,
      :level_aws_in_evm,
      :level_scvmm,
      :level_scvmm_in_evm,
      :level_api,
      :level_api_in_evm,
      :level_fog,
      :level_fog_in_evm,
    ]

    def self.init
      return if @initialized
      create_loggers
      apply_config
      @initialized = true
    end

    def self.apply_config(config = nil)
      config ||= get_config
      valid,   = validate_level(config)
      raise "configuration settings are invalid" unless valid

      apply_config_value(config, $log,       :level)
      apply_config_value(config, $rails_log, :level_rails)
      apply_config_value(config, $vim_log,   :level_vim,   :level_vim_in_evm)
      apply_config_value(config, $rhevm_log, :level_rhevm, :level_rhevm_in_evm)
      apply_config_value(config, $aws_log,   :level_aws,   :level_aws_in_evm)
      apply_config_value(config, $scvmm_log, :level_scvmm, :level_scvmm_in_evm)
      apply_config_value(config, $api_log,   :level_api,   :level_api_in_evm)
      apply_config_value(config, $fog_log,   :level_fog,   :level_fog_in_evm)
    end

    def self.validate_config(config)
      valid = true
      errors = []

      [:level, :path].each do |section|
        section_valid, section_errors = self.send("validate_#{section}", config)
        valid &&= section_valid
        errors += section_errors
      end

      return valid, errors
    end

    private

    def self.get_config
      VMDB::Config.new("vmdb").config[:log]
    end

    def self.create_loggers
      config = get_config
      valid, = validate_path(config)
      raise "configuration settings are invalid" unless valid

      path     = config[:path] || DEFAULT_LOG_PATH
      path_dir = File.dirname(path)

      $log           = VMDBLogger.new(File.join(path_dir, "evm.log"))
      $rails_log     = VMDBLogger.new(path)
      $audit_log     = AuditLogger.new(File.join(path_dir, "audit.log"))
      $fog_log       = FogLogger.new(File.join(path_dir, "fog.log"))
      $policy_log    = MirroredLogger.new(File.join(path_dir, "policy.log"),     "<PolicyEngine> ")
      $vim_log       = MirroredLogger.new(File.join(path_dir, "vim.log"),        "<VIM> ")
      $rhevm_log     = MirroredLogger.new(File.join(path_dir, "rhevm.log"),      "<RHEVM> ")
      $aws_log       = MirroredLogger.new(File.join(path_dir, "aws.log"),        "<AWS> ")
      $scvmm_log     = MirroredLogger.new(File.join(path_dir, "scvmm.log"),      "<SCVMM> ")
      $api_log       = MirroredLogger.new(File.join(path_dir, "api.log"),        "<API> ")
      $miq_ae_logger = MirroredLogger.new(File.join(path_dir, "automation.log"), "<AutomationEngine> ")
      $miq_ae_logger.mirror_level = VMDBLogger::INFO
    end

    def self.apply_config_value(config, logger, key, mirror_key = nil)
      apply_config_value_logged(config, logger, :level, key)
      apply_config_value_logged(config, logger, :mirror_level, mirror_key) if mirror_key
    end

    def self.apply_config_value_logged(config, logger, level_method, key)
      old_level = logger.send(level_method)
      new_level, new_level_name = level_and_name_for(config, key)
      if old_level != new_level
        $log.info("MIQ(#{self.name}.apply_config) Log level for #{File.basename(logger.filename)} has been changed to [#{new_level_name}]")
        logger.send("#{level_method}=", new_level)
      end
    end

    def self.level_and_name_for(config, key)
      name = (config[key] || DEFAULT_LOG_LEVEL).to_s.upcase
      level = VMDBLogger.const_get(name)
      return level, name
    end

    def self.validate_level(config)
      valid = true
      errors = []

      LEVEL_CONFIG_KEYS.each do |key|
        config[key] = config[key].upcase unless config[key].nil?

        level = config[key]
        if level && !VMDBLogger::Severity.constants.collect(&:to_s).include?(level)
          valid = false
          errors << [key, "#{key}, \"#{level}\", is invalid. Should be one of: #{VMDBLogger::Severity.constants.join(", ")}"]
        end
      end

      return valid, errors
    end

    def self.validate_path(config)
      valid = true
      errors = []

      path = config[:path].to_s
      unless path.blank?
        if !File.exist?(File.dirname(path))
          valid = false
          errors << [:path, "path, \"#{path}\", is invalid, directory does not exist"]
        end

        if File.extname(path).downcase != ".log"
          valid = false
          errors << [:path, "path, \"#{path}\", is invalid, must be in the form of <directory path>/<log file name>.log"]
        end
      end

      return valid, errors
    end
  end
end
