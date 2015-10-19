class CloudNetwork < ActiveRecord::Base
  include NewWithTypeStiMixin
  include ReportableMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  belongs_to :cloud_tenant
  belongs_to :orchestration_stack

  has_many   :cloud_subnets, :dependent => :destroy
  has_many   :network_ports, :dependent => :destroy
  has_many   :floating_ips,  :dependent => :destroy

  # TODO(lsmola) Defaulting CloudNetwork for Private network behaviour, otherwise I am unable to model
  # vm.public_networks. Not specifying it here causes missing method, ans specifying CloudNetwrok::Private
  # causes filtering networks by Provate, while I want to filter Public.
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

  def ip_address_total_count
    # TODO(lsmola) Rather storing this in DB? It should be changing only in refresh
    @ip_address_total_count ||= cloud_subnets.all.sum do |subnet|
      # We substract 1 because the first address of the pool is always reserved. For private network it is for DHCP, for
      # public network it's a port for Router.
      subnet.allocation_pools.sum { |x| (IPAddr.new(x["start"])..IPAddr.new(x["end"])).map(&:to_s).count - 1}
    end
  end

  def ip_address_left_count(reload = false)
    @ip_address_left_count = nil if reload
    @ip_address_left_count ||= ip_address_total_count - ip_address_used_count(reload)
  end

  def ip_address_utilization(reload = false)
    @ip_address_utilization = nil if reload
    # If total count is 0, utilization should be 100
    @ip_address_utilization ||= ip_address_total_count > 0 ? (100.0 / ip_address_total_count) * ip_address_used_count(reload) : 100
  end

  def ip_address_left_count_live(reload = false)
    @ip_address_left_count_live = nil if reload
    # Live method is asking API drectly for current count of consumed addresses
    @ip_address_left_count_live ||= ip_address_total_count - ip_address_used_count_live(reload)
  end

  def ip_address_utilization_live(reload = false)
    @ip_address_utilization_live = nil if reload
    # Live method is asking API drectly for current count of consumed addresses
    # If total count is 0, utilization should be 100
    @ip_address_utilization_live ||= ip_address_total_count > 0 ? (100.0 / ip_address_total_count) * ip_address_used_count_live(reload) : 100
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
