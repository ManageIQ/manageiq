class ManageIQ::Providers::Foreman::ConfigurationManager < ManageIQ::Providers::ConfigurationManager
  require_nested :ConfigurationProfile
  require_nested :ConfiguredSystem
  require_nested :ProvisionTask
  require_nested :ProvisionWorkflow
  require_nested :Refresher
  require_nested :RefreshParser
  require_nested :RefreshWorker

  include ProcessTasksMixin
  delegate :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :connect,
           :verify_credentials,
           :with_provider_connection,
           :to => :provider

  def self.ems_type
    @ems_type ||= "foreman_configuration".freeze
  end

  def self.description
    @description ||= "Foreman Configuration".freeze
  end
end
