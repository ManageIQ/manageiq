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
      apply_config_value(config, $policy_log,         :level_policy)
      apply_config_value(config, $remote_console_log, :level_remote_console)

      # TODO: Move this into the manageiq-api plugin
      apply_config_value(config, $api_log,            :level_api)
      # TODO: Move this into the manageiq-automation_engine plugin
      apply_config_value(config, $miq_ae_logger,      :level_automation)
      # TODO: Move these to their respective provider plugins
      apply_config_value(config, $ansible_tower_log,  :level_ansible_tower)
      apply_config_value(config, $azure_log,          :level_azure)
      apply_config_value(config, $azure_stack_log,    :level_azure_stack)
      apply_config_value(config, $cn_monitoring_log,  :level_cn_monitoring)
      apply_config_value(config, $datawarehouse_log,  :level_datawarehouse)
      apply_config_value(config, $fog_log,            :level_fog)
      apply_config_value(config, $gce_log,            :level_gce)
      apply_config_value(config, $ibm_cloud_log,      :level_ibm_cloud)
      apply_config_value(config, $ibm_terraform_log,  :level_ibm_terraform)
      apply_config_value(config, $kube_log,           :level_kube)
      apply_config_value(config, $lenovo_log,         :level_lenovo)
      apply_config_value(config, $nsxt_log,           :level_nsxt)
      apply_config_value(config, $nuage_log,          :level_nuage)
      apply_config_value(config, $redfish_log,        :level_redfish)
      apply_config_value(config, $rhevm_log,          :level_rhevm)
      apply_config_value(config, $scvmm_log,          :level_scvmm)
      apply_config_value(config, $vcloud_log,         :level_vcloud)
      apply_config_value(config, $vim_log,            :level_vim)

      Vmdb::Plugins.each { |p| p.try(:apply_logger_config, config) }
    end

    def self.create_logger(log_file_name, logger_class = VMDBLogger)
      log_file = ManageIQ.root.join("log", log_file_name)
      logger_class.new(log_file).tap do |logger|
        logger.extend(ActiveSupport::Logger.broadcast($container_log)) if $container_log
        logger.extend(ActiveSupport::Logger.broadcast($journald_log))  if $journald_log
      end
    end

    private_class_method def self.create_loggers
      $container_log      = create_container_logger
      $journald_log       = create_journald_logger
      $log                = create_logger("evm.log")
      $rails_log          = create_logger("#{Rails.env}.log")
      $audit_log          = create_logger("audit.log", AuditLogger)
      $policy_log         = create_logger("policy.log")
      $remote_console_log = create_logger("remote_console.log")

      # TODO: Move this into the manageiq-api plugin
      $api_log            = create_logger("api.log")
      # TODO: Move this into the manageiq-automation_engine plugin
      $miq_ae_logger      = create_logger("automation.log")
      # TODO: Move these to their respective provider plugins
      $ansible_tower_log  = create_logger("ansible_tower.log")
      $azure_log          = create_logger("azure.log", ProviderSdkLogger)
      $azure_stack_log    = create_logger("azure_stack.log")
      $cn_monitoring_log  = create_logger("container_monitoring.log")
      $datawarehouse_log  = create_logger("datawarehouse.log")
      $fog_log            = create_logger("fog.log", FogLogger)
      $gce_log            = create_logger("gce.log")
      $ibm_cloud_log      = create_logger("ibm_cloud.log", ProviderSdkLogger)
      $ibm_terraform_log  = create_logger("ibm_terraform.log", ProviderSdkLogger)
      $kube_log           = create_logger("kubernetes.log")
      $lenovo_log         = create_logger("lenovo.log")
      $nsxt_log           = create_logger("nsxt.log")
      $nuage_log          = create_logger("nuage.log")
      $redfish_log        = create_logger("redfish.log")
      $rhevm_log          = create_logger("rhevm.log")
      $scvmm_log          = create_logger("scvmm.log")
      $vcloud_log         = create_logger("vcloud.log")
      $vim_log            = create_logger("vim.log")

      configure_external_loggers
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
