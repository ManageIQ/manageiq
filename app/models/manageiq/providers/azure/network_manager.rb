class ManageIQ::Providers::Azure::NetworkManager < ManageIQ::Providers::NetworkManager
  require_nested :CloudNetwork
  require_nested :CloudSubnet
  require_nested :FloatingIp
  require_nested :NetworkPort
  require_nested :NetworkRouter
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher
  require_nested :SecurityGroup

  include ManageIQ::Providers::Azure::ManagerMixin

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
           :azure_tenant_id,
           :to        => :parent_manager,
           :allow_nil => true

  def self.ems_type
    @ems_type ||= "azure_network".freeze
  end

  def self.description
    @description ||= "Azure Network".freeze
  end

  def self.hostname_required?
    false
  end

  def description
    ManageIQ::Providers::Azure::Regions.find_by_name(provider_region)[:description]
  end
end
