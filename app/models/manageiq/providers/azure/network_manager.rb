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

  alias_attribute :azure_tenant_id, :uid_ems

  has_many :resource_groups, :foreign_key => :ems_id, :dependent => :destroy

  belongs_to :parent_manager,
             :foreign_key => :parent_ems_id,
             :class_name  => "ManageIQ::Providers::BaseManager",
             :autosave    => true

  # Auth and endpoints delegations, editing of this type of manager must be disabled
  delegate :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :authentications,
           :authentication_for_summary,
           :zone,
           :Amazon_handle,
           :connect,
           :verify_credentials,
           :with_provider_connection,
           :address,
           :ip_address,
           :hostname,
           :default_endpoint,
           :endpoints,
           :to        => :parent_manager,
           :allow_nil => true

  # Relationships delegated to parent manager
  delegate :availability_zones,
           :cloud_tenants,
           :flavors,
           :cloud_resource_quotas,
           :cloud_volumes,
           :cloud_volume_snapshots,
           :cloud_object_store_containers,
           :cloud_object_store_objects,
           :key_pairs,
           :orchestration_stacks,
           :direct_orchestration_stacks,
           :vms,
           :hosts,
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
