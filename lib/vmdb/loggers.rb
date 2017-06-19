require 'util/vmdb-logger'

Dir.glob(File.join(File.dirname(__FILE__), "loggers", "*")).each { |f| require f }

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
      apply_config_value(config, $log,               :level)
      apply_config_value(config, $rails_log,         :level_rails)
      apply_config_value(config, $vim_log,           :level_vim)
      apply_config_value(config, $rhevm_log,         :level_rhevm)
      apply_config_value(config, $aws_log,           :level_aws)
      apply_config_value(config, $kube_log,          :level_kube)
      apply_config_value(config, $mw_log,            :level_mw)
      apply_config_value(config, $datawarehouse_log, :level_datawarehouse)
      apply_config_value(config, $scvmm_log,         :level_scvmm)
      apply_config_value(config, $api_log,           :level_api)
      apply_config_value(config, $fog_log,           :level_fog)
      apply_config_value(config, $azure_log,         :level_azure)
      apply_config_value(config, $lenovo_log,        :level_lenovo)
      apply_config_value(config, $websocket_log,     :level_websocket)
    end

    private

    def self.create_loggers
      path_dir = Rails.root.join("log")

      $log               = VMDBLogger.new(path_dir.join("evm.log"))
      $rails_log         = VMDBLogger.new(path_dir.join("#{Rails.env}.log"))
      $audit_log         = AuditLogger.new(path_dir.join("audit.log"))
      $fog_log           = FogLogger.new(path_dir.join("fog.log"))
      $policy_log        = VMDBLogger.new(path_dir.join("policy.log"))
      $vim_log           = VMDBLogger.new(path_dir.join("vim.log"))
      $rhevm_log         = VMDBLogger.new(path_dir.join("rhevm.log"))
      $aws_log           = VMDBLogger.new(path_dir.join("aws.log"))
      $lenovo_log        = VMDBLogger.new(path_dir.join("lenovo.log"))
      $kube_log          = VMDBLogger.new(path_dir.join("kubernetes.log"))
      $mw_log            = VMDBLogger.new(path_dir.join("middleware.log"))
      $datawarehouse_log = VMDBLogger.new(path_dir.join("datawarehouse.log"))
      $scvmm_log         = VMDBLogger.new(path_dir.join("scvmm.log"))
      $azure_log         = VMDBLogger.new(path_dir.join("azure.log"))
      $api_log           = VMDBLogger.new(path_dir.join("api.log"))
      $websocket_log     = VMDBLogger.new(path_dir.join("websocket.log"))
      $miq_ae_logger     = VMDBLogger.new(path_dir.join("automation.log"))

      configure_external_loggers
    end

    def self.configure_external_loggers
      require 'awesome_spawn'
      AwesomeSpawn.logger = $log
    end

    private_class_method :configure_external_loggers


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
