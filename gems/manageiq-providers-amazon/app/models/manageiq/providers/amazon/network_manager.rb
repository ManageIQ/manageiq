class ManageIQ::Providers::Amazon::NetworkManager < ManageIQ::Providers::NetworkManager
  require_nested :CloudNetwork
  require_nested :CloudSubnet
  require_nested :FloatingIp
  require_nested :NetworkPort
  require_nested :NetworkRouter
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher
  require_nested :SecurityGroup

  include ManageIQ::Providers::Amazon::ManagerMixin

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
    @ems_type ||= "ec2_network".freeze
  end

  def self.description
    @description ||= "Amazon EC2 Network".freeze
  end

  def self.hostname_required?
    false
  end

  def self.default_blacklisted_event_names
    %w(
      ConfigurationSnapshotDeliveryCompleted
      ConfigurationSnapshotDeliveryStarted
      ConfigurationSnapshotDeliveryFailed
    )
  end
end
