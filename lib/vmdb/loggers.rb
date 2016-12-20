require 'util/vmdb-logger'

Dir.glob(File.join(File.dirname(__FILE__), "loggers", "*")).each { |f| require f }

module Vmdb
  def self.logger
    $log
  end

  def self.null_logger
    @null_logger ||= Loggers::NullLogger.new
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
      apply_config_value(config, $log,           :level)
      apply_config_value(config, $rails_log,     :level_rails)
      apply_config_value(config, $vim_log,       :level_vim,       :level_vim_in_evm)
      apply_config_value(config, $rhevm_log,     :level_rhevm,     :level_rhevm_in_evm)
      apply_config_value(config, $aws_log,       :level_aws,       :level_aws_in_evm)
      apply_config_value(config, $kube_log,      :level_kube,      :level_kube_in_evm)
      apply_config_value(config, $mw_log,        :level_mw,        :level_mw_in_evm)
      apply_config_value(config, $scvmm_log,     :level_scvmm,     :level_scvmm_in_evm)
      apply_config_value(config, $api_log,       :level_api,       :level_api_in_evm)
      apply_config_value(config, $fog_log,       :level_fog,       :level_fog_in_evm)
      apply_config_value(config, $azure_log,     :level_azure,     :level_azure_in_evm)
      apply_config_value(config, $websocket_log, :level_websocket, :level_websocket_in_evm)
    end

    private

    def self.create_loggers
      if ENV.key?("CI")
        $log       = $rails_log = $audit_log = $fog_log = $policy_log = $vim_log = $rhevm_log = Vmdb.null_logger
        $aws_log   = $kube_log = $mw_log = $scvmm_log = $api_log = $miq_ae_logger = $websocket_log = Vmdb.null_logger
        $azure_log = Vmdb.null_logger
      else
        path_dir = Rails.root.join("log")

        $log           = VMDBLogger.new(path_dir.join("evm.log"))
        $rails_log     = VMDBLogger.new(path_dir.join("#{Rails.env}.log"))
        $audit_log     = AuditLogger.new(path_dir.join("audit.log"))
        $fog_log       = FogLogger.new(path_dir.join("fog.log"))
        $policy_log    = MirroredLogger.new(path_dir.join("policy.log"),     "<PolicyEngine> ")
        $vim_log       = MirroredLogger.new(path_dir.join("vim.log"),        "<VIM> ")
        $rhevm_log     = MirroredLogger.new(path_dir.join("rhevm.log"),      "<RHEVM> ")
        $aws_log       = MirroredLogger.new(path_dir.join("aws.log"),        "<AWS> ")
        $kube_log      = MirroredLogger.new(path_dir.join("kubernetes.log"), "<KUBERNETES> ")
        $mw_log        = MirroredLogger.new(path_dir.join("middleware.log"), "<MIDDLEWARE> ")
        $scvmm_log     = MirroredLogger.new(path_dir.join("scvmm.log"),      "<SCVMM> ")
        $azure_log     = MirroredLogger.new(path_dir.join("azure.log"),      "<AZURE> ")
        $api_log       = MirroredLogger.new(path_dir.join("api.log"),        "<API> ")
        $websocket_log = MirroredLogger.new(path_dir.join("websocket.log"),  "<WEBSOCKET> ")
        $miq_ae_logger = MirroredLogger.new(path_dir.join("automation.log"), "<AutomationEngine> ")
        $miq_ae_logger.mirror_level = VMDBLogger::INFO
      end

      configure_external_loggers
    end

    def self.configure_external_loggers
      require 'awesome_spawn'
      AwesomeSpawn.logger = $log
    end

    private_class_method :configure_external_loggers

    def self.apply_config_value(config, logger, key, mirror_key = nil)
      return if logger.kind_of?(Vmdb::Loggers::NullLogger)
      apply_config_value_logged(config, logger, :level, key)
      apply_config_value_logged(config, logger, :mirror_level, mirror_key) if mirror_key
    end

    def self.apply_config_value_logged(config, logger, level_method, key)
      old_level      = logger.send(level_method)
      new_level_name = (config[key] || "INFO").to_s.upcase
      new_level      = VMDBLogger.const_get(new_level_name)
      if old_level != new_level
        $log.info("MIQ(#{name}.apply_config) Log level for #{File.basename(logger.filename)} has been changed to [#{new_level_name}]")
        logger.send("#{level_method}=", new_level)
      end
    end
  end
end
