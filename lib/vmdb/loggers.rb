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
      apply_config_value(config, $journald_log,       :level) if $journald_log
      apply_config_value(config, $rails_log,          :level_rails)
      apply_config_value(config, $ansible_tower_log,  :level_ansible_tower)
      apply_config_value(config, $api_log,            :level_api)
      apply_config_value(config, $miq_ae_logger,      :level_automation)
      apply_config_value(config, $aws_log,            :level_aws)
      apply_config_value(config, $azure_log,          :level_azure)
      apply_config_value(config, $azure_stack_log,    :level_azure_stack)
      apply_config_value(config, $cn_monitoring_log,  :level_cn_monitoring)
      apply_config_value(config, $datawarehouse_log,  :level_datawarehouse)
      apply_config_value(config, $fog_log,            :level_fog)
      apply_config_value(config, $gce_log,            :level_gce)
      apply_config_value(config, $ibm_cloud_log,      :level_ibm_cloud)
      apply_config_value(config, $kube_log,           :level_kube)
      apply_config_value(config, $lenovo_log,         :level_lenovo)
      apply_config_value(config, $nsxt_log,           :level_nsxt)
      apply_config_value(config, $nuage_log,          :level_nuage)
      apply_config_value(config, $policy_log,         :level_policy)
      apply_config_value(config, $redfish_log,        :level_redfish)
      apply_config_value(config, $rhevm_log,          :level_rhevm)
      apply_config_value(config, $scvmm_log,          :level_scvmm)
      apply_config_value(config, $vcloud_log,         :level_vcloud)
      apply_config_value(config, $vim_log,            :level_vim)
      apply_config_value(config, $remote_console_log, :level_remote_console)
    end

    def self.create_loggers
      path_dir = ManageIQ.root.join("log")

      $container_log      = ContainerLogger.new
      $journald_log       = create_journald_logger
      $log                = create_multicast_logger(path_dir.join("evm.log"))
      $rails_log          = create_multicast_logger(path_dir.join("#{Rails.env}.log"))
      $audit_log          = create_multicast_logger(path_dir.join("audit.log"), AuditLogger)
      $api_log            = create_multicast_logger(path_dir.join("api.log"))
      $ansible_tower_log  = create_multicast_logger(path_dir.join("ansible_tower.log"))
      $miq_ae_logger      = create_multicast_logger(path_dir.join("automation.log"))
      $aws_log            = create_multicast_logger(path_dir.join("aws.log"))
      $azure_log          = create_multicast_logger(path_dir.join("azure.log"), ProviderSdkLogger)
      $azure_stack_log    = create_multicast_logger(path_dir.join("azure_stack.log"))
      $cn_monitoring_log  = create_multicast_logger(path_dir.join("container_monitoring.log"))
      $datawarehouse_log  = create_multicast_logger(path_dir.join("datawarehouse.log"))
      $fog_log            = create_multicast_logger(path_dir.join("fog.log"), FogLogger)
      $gce_log            = create_multicast_logger(path_dir.join("gce.log"))
      $ibm_cloud_log      = create_multicast_logger(path_dir.join("ibm_cloud.log"), ProviderSdkLogger)
      $kube_log           = create_multicast_logger(path_dir.join("kubernetes.log"))
      $lenovo_log         = create_multicast_logger(path_dir.join("lenovo.log"))
      $nsxt_log           = create_multicast_logger(path_dir.join("nsxt.log"))
      $nuage_log          = create_multicast_logger(path_dir.join("nuage.log"))
      $policy_log         = create_multicast_logger(path_dir.join("policy.log"))
      $redfish_log        = create_multicast_logger(path_dir.join("redfish.log"))
      $rhevm_log          = create_multicast_logger(path_dir.join("rhevm.log"))
      $scvmm_log          = create_multicast_logger(path_dir.join("scvmm.log"))
      $vcloud_log         = create_multicast_logger(path_dir.join("vcloud.log"))
      $vim_log            = create_multicast_logger(path_dir.join("vim.log"))
      $remote_console_log = create_multicast_logger(path_dir.join("remote_console.log"))

      configure_external_loggers
    end
    private_class_method :create_loggers

    def self.create_multicast_logger(log_file_path, logger_class = VMDBLogger)
      logger_class.new(log_file_path).tap do |logger|
        logger.extend(ActiveSupport::Logger.broadcast($container_log)) if ENV["CONTAINER"]
        logger.extend(ActiveSupport::Logger.broadcast($journald_log))  if $journald_log
      end
    end
    private_class_method :create_multicast_logger

    private_class_method def self.create_journald_logger
      return unless MiqEnvironment::Command.supports_systemd?

      require "manageiq/loggers/journald"
      ManageIQ::Loggers::Journald.new
    rescue LoadError
      nil
    end

    def self.configure_external_loggers
      require 'awesome_spawn'
      AwesomeSpawn.logger = $log

      require 'log_decorator'
      LogDecorator.logger = $log

      require 'inventory_refresh'
      InventoryRefresh.logger = $log
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
    private_class_method :apply_config_value
  end
end

require_relative "loggers/instrument"
Dir.glob(File.join(File.dirname(__FILE__), "loggers", "*")).each { |f| require f }
