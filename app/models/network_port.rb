class NetworkPort < ApplicationRecord
  include NewWithTypeStiMixin
  include ReportableMixin

  # TODO(lsmola) NetworkManager, once all providers use network manager rename this to
  # "ManageIQ::Providers::NetworkManager"
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::BaseManager"
  belongs_to :cloud_tenant
  belongs_to :device, :polymorphic => true

  has_and_belongs_to_many :security_groups

  has_one :floating_ip
  # TODO(lsmola) can this really happen? If not remove it
  has_many :floating_ips
  has_many :cloud_subnet_network_ports
  has_many :cloud_subnets, :through => :cloud_subnet_network_ports
  has_many :network_routers, :through => :cloud_subnets


  # Use for virtual columns, mainly for modeling array and hash types, we get from the API
  serialize :extra_attributes

  virtual_column :binding_virtual_interface_details, :type => :string # :hash
  virtual_column :binding_virtual_nic_type,          :type => :string
  virtual_column :binding_profile,                   :type => :string # :hash
  virtual_column :extra_dhcp_opts,                   :type => :string # :array
  virtual_column :allowed_address_pairs,             :type => :string # :array
  virtual_column :fixed_ips,                         :type => :string # :array

  # Define all getters and setters for extra_attributes related virtual columns
  %i(binding_virtual_interface_details binding_virtual_nic_type binding_profile extra_dhcp_opts
     allowed_address_pairs fixed_ips).each do |action|
	  define_method("#{action.to_s}=") do |value|
      extra_attributes_save(action, value)
    end

    define_method("#{action.to_s}") do
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
