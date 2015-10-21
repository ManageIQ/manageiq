class NetworkRouter < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  belongs_to :cloud_tenant
  belongs_to :cloud_network
  alias_method :public_network, :cloud_network

  has_many :floating_ips
  has_many :network_ports, :as => :device
  has_many :cloud_networks, :through => :network_ports
  alias_method :private_networks, :cloud_networks
  has_many :vms_network_ports, :through => :cloud_networks, :source => :network_ports
  has_many :vms, :through => :vms_network_ports, :source => :device, :source_type => 'VmOrTemplate'

  # Use for virtual columns, mainly for modeling array and hash types, we get from the API
  serialize :extra_attributes

  virtual_column :external_gateway_info, :type => :string # :hash
  virtual_column :distributed          , :type => :boolean
  virtual_column :routes               , :type => :string # :array
  virtual_column :high_availability    , :type => :boolean

  # Define all getters and setters for extra_attributes related virtual columns
  %i(external_gateway_info distributed routes high_availability).each do |action|
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
