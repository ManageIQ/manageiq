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
  include SupportsFeatureMixin

  supports :create
  supports :create_network_router

  has_many :public_networks,  :foreign_key => :ems_id, :dependent => :destroy,
           :class_name => "ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Public"
  has_many :private_networks, :foreign_key => :ems_id, :dependent => :destroy,
           :class_name => "ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Private"
  alias_method :all_private_networks, :private_networks

  # Auth and endpoints delegations, editing of this type of manager must be disabled
  delegate :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :authentications,
           :authentication_for_summary,
           :zone,
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

  # Builds create_<network item>_queue and associated raw_create_<network item> methods
  [:CloudNetwork, :CloudSubnet, :FloatingIp, :NetworkRouter, :SecurityGroup].each do |subclass|
    name = /([A-Z].*)([A-Z].*)/.match(subclass.to_s)
    method_name = "#{name[1].downcase}_#{name[2].downcase}"
    klass = Object.const_get("#{self}::#{subclass}")

    define_method("create_#{method_name}") do |options|
      klass.send("raw_create_#{method_name}".to_sym, self, options)
    end

    define_method("create_#{method_name}_queue") do |userid, options = {}|
      task_opts = {
        :action => "creating #{ui_lookup(:model => "subclass")} for user #{userid}",
        :userid => userid
      }
      queue_opts = {
        :class_name  => self.class.name,
        :method_name => "create_#{method_name}",
        :instance_id => id,
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => 'ems_operations',
        :zone        => my_zone,
        :args        => [options]
      }
      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end
  end
end
