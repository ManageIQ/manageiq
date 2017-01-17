class NetworkPort < ApplicationRecord
  include NewWithTypeStiMixin
  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
  belongs_to :cloud_tenant
  belongs_to :device, :polymorphic => true

  has_many :network_port_security_groups, :dependent => :destroy
  has_many :security_groups, :through => :network_port_security_groups

  has_one :floating_ip
  # TODO(lsmola) can this really happen? If not remove it
  has_many :floating_ips
  has_many :cloud_subnet_network_ports, :dependent => :destroy
  has_many :cloud_subnets, :through => :cloud_subnet_network_ports
  has_many :network_routers, -> { distinct }, :through => :cloud_subnets
  has_many :public_networks, :through => :cloud_subnets

  # Use for virtual columns, mainly for modeling array and hash types, we get from the API
  serialize :extra_attributes

  virtual_column :binding_virtual_interface_details, :type => :string # :hash
  virtual_column :binding_virtual_nic_type,          :type => :string
  virtual_column :binding_profile,                   :type => :string # :hash
  virtual_column :extra_dhcp_opts,                   :type => :string # :array
  virtual_column :allowed_address_pairs,             :type => :string # :array
  virtual_column :fixed_ips,                         :type => :string # :array

  virtual_column :ipaddresses, :type => :string_set, :uses => [:cloud_subnet_network_ports, :floating_ips]
  virtual_column :fixed_ip_addresses, :type => :string_set, :uses => :cloud_subnet_network_ports
  virtual_column :floating_ip_addresses, :type => :string_set, :uses => :floating_ips
  virtual_column :cloud_subnets_names, :type => :string_set, :uses => :cloud_subnets

  def floating_ip_addresses
    @floating_ip_addresses ||= floating_ips.collect(&:address).compact.uniq
  end

  def fixed_ip_addresses
    @fixed_ip_addresses ||= cloud_subnet_network_ports.collect(&:address).compact.uniq
  end

  def ipaddresses
    @ipaddresses ||= (fixed_ip_addresses || []) + (floating_ip_addresses || [])
  end

  def cloud_subnets_names
    @cloud_subnets_names ||= cloud_subnets.collect(&:name).compact.uniq
  end

  # Define all getters and setters for extra_attributes related virtual columns
  %i(binding_virtual_interface_details binding_virtual_nic_type binding_profile extra_dhcp_opts
     allowed_address_pairs fixed_ips).each do |action|
	  define_method("#{action}=") do |value|
      extra_attributes_save(action, value)
    end

    define_method(action) do
      extra_attributes_load(action)
    end
  end

  private

  def extra_attributes_save(key, value)
    self.extra_attributes = {} if extra_attributes.blank?
    self.extra_attributes[key] = value
  end

  def extra_attributes_load(key)
    self.extra_attributes[key] unless extra_attributes.blank?
  end
end
