class CloudSubnet < ApplicationRecord
  include NewWithTypeStiMixin
  include ReportableMixin

  acts_as_miq_taggable

  # TODO(lsmola) NetworkManager, once all providers use network manager rename this to
  # "ManageIQ::Providers::NetworkManager"
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::BaseManager"
  belongs_to :cloud_network
  belongs_to :cloud_tenant
  belongs_to :availability_zone
  belongs_to :network_router

  has_many :cloud_subnet_network_ports, :dependent => :destroy
  has_many :network_ports, :through => :cloud_subnet_network_ports, :dependent => :destroy
  has_many :vms, :through => :network_ports, :source => :device, :source_type => 'VmOrTemplate'

  # Use for virtual columns, mainly for modeling array and hash types, we get from the API
  serialize :extra_attributes
  serialize :dns_nameservers

  virtual_column :allocation_pools, :type => :string
  virtual_column :host_routes,      :type => :string
  virtual_column :ip_version,       :type => :string
  virtual_column :subnetpool_id,    :type => :string

  # Define all getters and setters for extra_attributes related virtual columns
  %i(allocation_pools host_routes ip_version subnetpool_id).each do |action|
    define_method("#{action.to_s}=") do |value|
      extra_attributes_save(action, value)
    end

    define_method("#{action.to_s}") do
      extra_attributes_load(action)
    end
  end

  def dns_nameservers_show
    dns_nameservers.join(", ") if dns_nameservers
  end
  virtual_column :dns_nameservers_show, :type => :string, :uses => :dns_nameservers

  def total_vms
    vms.count
  end
  virtual_column :total_vms, :type => :integer, :uses => :vms

  private

  def extra_attributes_save(key, value)
    self.extra_attributes = {} if extra_attributes.blank?
    self.extra_attributes[key] = value
  end

  def extra_attributes_load(key)
    self.extra_attributes[key] unless extra_attributes.blank?
  end
end
