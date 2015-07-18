class ManageIQ::Providers::Foreman::ConfigurationManager < ManageIQ::Providers::ConfigurationManager
  require_dependency 'manageiq/providers/foreman/configuration_manager/configuration_profile'
  require_dependency 'manageiq/providers/foreman/configuration_manager/configured_system'
  require_dependency 'manageiq/providers/foreman/configuration_manager/refresher'
  require_dependency 'manageiq/providers/foreman/configuration_manager/refresh_parser'
  require_dependency 'manageiq/providers/foreman/configuration_manager/refresh_worker'

  include ProcessTasksMixin
  delegate :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :connect,
           :verify_credentials,
           :with_provider_connection,
           :to => :provider

  def self.ems_type
    "foreman_configuration".freeze
  end
end
