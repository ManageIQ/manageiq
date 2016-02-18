class ManageIQ::Providers::Foreman::ProvisioningManager < ManageIQ::Providers::ProvisioningManager
  require_nested :Refresher
  require_nested :RefreshParser
  require_nested :RefreshWorker

  delegate :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :connect,
           :verify_credentials,
           :with_provider_connection,
           :to => :provider

  has_many :configuration_locations,    :foreign_key => :provisioning_manager_id
  has_many :configuration_organizations, :foreign_key => :provisioning_manager_id

  def self.ems_type
    @ems_type ||= "foreman_provisioning".freeze
  end

  def self.description
    @description ||= "Foreman Provisioning".freeze
  end
end
