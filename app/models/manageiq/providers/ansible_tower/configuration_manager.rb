class ManageIQ::Providers::AnsibleTower::ConfigurationManager < ManageIQ::Providers::ConfigurationManager
  require_nested :ConfiguredSystem

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
