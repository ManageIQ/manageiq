class ProvisioningManagerForeman < ProvisioningManager
  delegate :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :connect,
           :verify_credentials,
           :with_provider_connection,
           :to => :provider

  def self.ems_type
    "foreman_provisioning".freeze
  end
end
