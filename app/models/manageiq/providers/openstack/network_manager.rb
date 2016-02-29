class ManageIQ::Providers::Openstack::NetworkManager < ManageIQ::Providers::NetworkManager
  require_nested :CloudNetwork
  require_nested :CloudSubnet
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :FloatingIp
  require_nested :MetricsCapture
  require_nested :MetricsCollectorWorker
  require_nested :NetworkPort
  require_nested :NetworkRouter
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher
  require_nested :SecurityGroup

  include ManageIQ::Providers::Openstack::ManagerMixin

  belongs_to :parent_manager,
             :foreign_key => :parent_ems_id,
             :class_name  => "ManageIQ::Providers::BaseManager",
             :autosave    => true

  has_many :public_networks,  :foreign_key => :ems_id, :dependent => :destroy,
           :class_name => "ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Public"
  has_many :private_networks, :foreign_key => :ems_id, :dependent => :destroy,
           :class_name => "ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Private"

  # Auth and endpoints delegations, editing of this type of manager must be disabled
  delegate :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :authentications,
           :authentication_for_summary,
           :openstack_handle,
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

  def self.hostname_required?
    false
  end

  def self.ems_type
    @ems_type ||= "openstack_network".freeze
  end

  def self.description
    @description ||= "OpenStack Network".freeze
  end

  def self.default_blacklisted_event_names
    %w(
      scheduler.run_instance.start
      scheduler.run_instance.scheduled
      scheduler.run_instance.end
    )
  end

  def supports_port?
    true
  end

  def supports_api_version?
    true
  end

  def supports_security_protocol?
    true
  end

  def supported_auth_types
    %w(default amqp)
  end

  def supports_provider_id?
    true
  end

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
  end

  def self.event_monitor_class
    ManageIQ::Providers::Openstack::NetworkManager::EventCatcher
  end
end
