class CloudNetwork < ApplicationRecord
  include NewWithTypeStiMixin
  include ReportableMixin

  # TODO(lsmola) NetworkManager, once all providers use network manager rename this to "ManageIQ::Providers::NetworkManager"
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::BaseManager"
  belongs_to :cloud_tenant
  belongs_to :orchestration_stack

  has_many   :cloud_subnets, :dependent => :destroy
  has_many   :network_ports, :through => :cloud_subnets
  has_many   :floating_ips,  :dependent => :destroy

  # TODO(lsmola) Defaulting CloudNetwork for Private network behaviour, otherwise I am unable to model
  # vm.public_networks. Not specifying it here causes missing method, ans specifying CloudNetwork::Private
  # causes filtering networks by Private, while I want to filter Public.
  include CloudNetworkPrivateMixin

  # TODO(lsmola) figure out what this means, like security groups used by VMs in the network? It's not being
  # refreshed, so we can probably delete this association
  has_many   :security_groups

  # Use for virtual columns, mainly for modeling array and hash types, we get from the API
  serialize :extra_attributes

  virtual_column :maximum_transmission_unit, :type => :string
  virtual_column :port_security_enabled,     :type => :string

  # Define all getters and setters for extra_attributes related virtual columns
  %i(maximum_transmission_unit port_security_enabled).each do |action|
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
