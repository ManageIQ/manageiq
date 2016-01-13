class ManageIQ::Providers::AnsibleTower::ConfigurationManager < ManageIQ::Providers::ConfigurationManager
  require_nested :ConfiguredSystem
  require_nested :Refresher
  require_nested :RefreshParser
  require_nested :RefreshWorker

  include ProcessTasksMixin
  delegate :authentications,
           :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :connect,
           :verify_credentials,
           :with_provider_connection,
           :to => :provider

  def self.ems_type
    "ansible_tower_configuration".freeze
  end
end
