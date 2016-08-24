class ManageIQ::Providers::Vmware::NetworkManager < ManageIQ::Providers::NetworkManager
  require_nested :CloudNetwork
  require_nested :CloudSubnet
  require_nested :NetworkPort
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher

  include ManageIQ::Providers::Vmware::ManagerAuthMixin

  # Auth and endpoints delegations, editing of this type of manager must be disabled
  delegate :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :authentications,
           :authentication_for_summary,
           :zone,
           :connect,
           :verify_credentials,
           :with_provider_connection,
           :address,
           :ip_address,
           :hostname,
           :default_endpoint,
           :endpoints,
           :provider_region,
           :to        => :parent_manager,
           :allow_nil => true

  def self.ems_type
    @ems_type ||= "vmware_cloud_network".freeze
  end

  def self.description
    @description ||= "VMware Cloud Network".freeze
  end

  def self.hostname_required?
    false
  end

  def description
    @description ||= "VMware Cloud Network".freeze
  end
end
