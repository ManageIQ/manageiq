require 'manageiq'
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
      path_dir = ManageIQ.root.join("log")

      $audit_log         = AuditLogger.new(path_dir.join("audit.log"))
      $container_log     = ContainerLogger.new
      $log               = MulticastLogger.new(VMDBLogger.new(path_dir.join("evm.log"))).tap           { |l| l.loggers << $container_log if ENV["CONTAINER"] }
      $rails_log         = MulticastLogger.new(VMDBLogger.new(path_dir.join("#{Rails.env}.log"))).tap  { |l| l.loggers << $container_log if ENV["CONTAINER"] }
      $fog_log           = MulticastLogger.new(FogLogger.new(path_dir.join("fog.log"))).tap            { |l| l.loggers << $container_log if ENV["CONTAINER"] }
      $policy_log        = MulticastLogger.new(VMDBLogger.new(path_dir.join("policy.log"))).tap        { |l| l.loggers << $container_log if ENV["CONTAINER"] }
      $vim_log           = MulticastLogger.new(VMDBLogger.new(path_dir.join("vim.log"))).tap           { |l| l.loggers << $container_log if ENV["CONTAINER"] }
      $rhevm_log         = MulticastLogger.new(VMDBLogger.new(path_dir.join("rhevm.log"))).tap         { |l| l.loggers << $container_log if ENV["CONTAINER"] }
      $aws_log           = MulticastLogger.new(VMDBLogger.new(path_dir.join("aws.log"))).tap           { |l| l.loggers << $container_log if ENV["CONTAINER"] }
      $lenovo_log        = MulticastLogger.new(VMDBLogger.new(path_dir.join("lenovo.log"))).tap        { |l| l.loggers << $container_log if ENV["CONTAINER"] }
      $kube_log          = MulticastLogger.new(VMDBLogger.new(path_dir.join("kubernetes.log"))).tap    { |l| l.loggers << $container_log if ENV["CONTAINER"] }
      $mw_log            = MulticastLogger.new(VMDBLogger.new(path_dir.join("middleware.log"))).tap    { |l| l.loggers << $container_log if ENV["CONTAINER"] }
      $datawarehouse_log = MulticastLogger.new(VMDBLogger.new(path_dir.join("datawarehouse.log"))).tap { |l| l.loggers << $container_log if ENV["CONTAINER"] }
      $scvmm_log         = MulticastLogger.new(VMDBLogger.new(path_dir.join("scvmm.log"))).tap         { |l| l.loggers << $container_log if ENV["CONTAINER"] }
      $azure_log         = MulticastLogger.new(VMDBLogger.new(path_dir.join("azure.log"))).tap         { |l| l.loggers << $container_log if ENV["CONTAINER"] }
      $api_log           = MulticastLogger.new(VMDBLogger.new(path_dir.join("api.log"))).tap           { |l| l.loggers << $container_log if ENV["CONTAINER"] }
      $websocket_log     = MulticastLogger.new(VMDBLogger.new(path_dir.join("websocket.log"))).tap     { |l| l.loggers << $container_log if ENV["CONTAINER"] }
      $miq_ae_logger     = MulticastLogger.new(VMDBLogger.new(path_dir.join("automation.log"))).tap    { |l| l.loggers << $container_log if ENV["CONTAINER"] }

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

Dir.glob(File.join(File.dirname(__FILE__), "loggers", "*")).each { |f| require f }
