class CloudNetwork < ApplicationRecord
  include_concern 'Operations'

  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include AsyncDeleteMixin
  include VirtualTotalMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
  belongs_to :cloud_tenant
  belongs_to :orchestration_stack

  has_many :cloud_subnets, :dependent => :destroy
  has_many :network_routers, -> { distinct }, :through => :cloud_subnets
  has_many :public_networks, -> { distinct }, :through => :cloud_subnets
  has_many :network_ports, :through => :cloud_subnets
  has_many :floating_ips,  :dependent => :destroy
  has_many :vms, :through => :network_ports, :source => :device, :source_type => 'VmOrTemplate'

  # TODO(lsmola) figure out what this means, like security groups used by VMs in the network? It's not being
  # refreshed, so we can probably delete this association
  has_many   :security_groups

  # Use for virtual columns, mainly for modeling array and hash types, we get from the API
  serialize :extra_attributes

  virtual_column :maximum_transmission_unit, :type => :string
  virtual_column :port_security_enabled,     :type => :string
  virtual_column :qos_policy_id,             :type => :string

  # Define all getters and setters for extra_attributes related virtual columns
  %i(maximum_transmission_unit port_security_enabled qos_policy_id).each do |action|
	  define_method("#{action}=") do |value|
      extra_attributes_save(action, value)
    end

    define_method(action) do
      extra_attributes_load(action)
    end
  end

  virtual_total :total_vms, :vms, :uses => :vms

  def self.class_by_ems(ext_management_system, external = false)
    # TODO: A factory on ExtManagementSystem to return class for each provider
    if external
      ext_management_system && ext_management_system.class::CloudNetwork::Public
    else
      ext_management_system && ext_management_system.class::CloudNetwork::Private
    end
  end
  private_class_method :class_by_ems

  def self.create_network(ext_management_system, options = {})
    raise ArgumentError, _("ext_management_system cannot be nil") if ext_management_system.nil?

    klass = class_by_ems(ext_management_system, options[:external_facing])
    klass.raw_create_network(ext_management_system, options)
  end

  def self.validate_create_network(ext_management_system)
    klass = class_by_ems(ext_management_system)
    if ext_management_system && klass.respond_to?(:validate_create_network)
      return klass.validate_create_network(ext_management_system)
    end
    validate_unsupported("Create Network Operation")
  end

  def delete_network
    raw_delete_network
  end

  def extra_attributes_save(key, value)
    self.extra_attributes = {} if extra_attributes.blank?
    self.extra_attributes[key] = value
  end
  private :extra_attributes_save

  def extra_attributes_load(key)
    self.extra_attributes[key] unless extra_attributes.blank?
  end
  private :extra_attributes_load

  def validate_delete_network
    validate_unsupported("Delete Network Operation")
  end

  def raw_delete_network
    raise NotImplementedError, _("raw_delete_network must be implemented in a subclass")
  end

  def raw_update_network(_options = {})
    raise NotImplementedError, _("raw_update_network must be implemented in a subclass")
  end

  def update_network(options = {})
    raw_update_network(options) unless options.empty?
  end
end
