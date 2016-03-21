class NetworkRouter < ApplicationRecord
  include NewWithTypeStiMixin
  include ReportableMixin

  acts_as_miq_taggable

  # TODO(lsmola) NetworkManager, once all providers use network manager rename this to "ManageIQ::Providers::NetworkManager"
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::BaseManager"
  belongs_to :cloud_tenant

  has_many :cloud_subnets
  has_many :network_ports, :through => :cloud_subnets
  has_many :vms, :through => :cloud_subnets

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
