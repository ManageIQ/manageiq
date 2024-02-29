class CloudSubnet < ApplicationRecord
  include NewWithTypeStiMixin
  include SupportsFeatureMixin
  include CloudTenancyMixin
  include CustomActionsMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
  belongs_to :cloud_network
  belongs_to :cloud_tenant
  belongs_to :availability_zone
  belongs_to :network_group
  belongs_to :network_router
  belongs_to :parent_cloud_subnet, :class_name => "::CloudSubnet"

  has_many :cloud_subnet_network_ports, :dependent => :destroy
  has_many :network_ports, :through => :cloud_subnet_network_ports
  has_many :vms, -> { distinct }, :through => :network_ports, :source => :device, :source_type => 'VmOrTemplate'
  has_many :cloud_subnets, :foreign_key => :parent_cloud_subnet_id
  has_many :security_groups, :dependent => :nullify

  has_one :public_network, :through => :network_router, :source => :cloud_network

  # Use for virtual columns, mainly for modeling array and hash types, we get from the API
  serialize :extra_attributes
  serialize :dns_nameservers

  virtual_column :allocation_pools, :type => :string
  virtual_column :host_routes,      :type => :string
  virtual_column :ip_version,       :type => :string
  virtual_column :subnetpool_id,    :type => :string
  virtual_column :network_type,     :type => :string

  # Define all getters and setters for extra_attributes related virtual columns
  %i[allocation_pools host_routes ip_version subnetpool_id network_type].each do |action|
    define_method(:"#{action}=") do |value|
      extra_attributes_save(action, value)
    end

    define_method(action) do
      extra_attributes_load(action)
    end
  end

  def dns_nameservers_show
    dns_nameservers.join(", ") if dns_nameservers
  end
  virtual_column :dns_nameservers_show, :type => :string

  virtual_total :total_vms, :vms, :uses => :vms

  def self.class_by_ems(ext_management_system)
    ext_management_system&.class_by_ems(:CloudSubnet)
  end

  def delete_cloud_subnet_queue(userid)
    task_opts = {
      :action => "deleting Cloud Subnet for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_cloud_subnet',
      :instance_id => id,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => []
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def delete_cloud_subnet
    raw_delete_cloud_subnet
  end

  def raw_delete_cloud_subnet
    raise NotImplementedError, _("raw_delete_cloud_subnet must be implemented in a subclass")
  end

  private

  def extra_attributes_save(key, value)
    self.extra_attributes = {} if extra_attributes.blank?
    extra_attributes[key] = value
  end

  def extra_attributes_load(key)
    extra_attributes[key] if extra_attributes.present?
  end
end
