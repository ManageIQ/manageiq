class CloudNetwork < ApplicationRecord
  include NewWithTypeStiMixin

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

  def ip_address_used_count(reload = false)
    @ip_address_used_count = nil if reload
    if @public
      # Number of all floating Ips, since we are doing association by creating FloatingIP, because
      # associate is not atomic.
      @ip_address_used_count ||= floating_ips.count
    else
      @ip_address_used_count ||= vms.count
    end
  end
 
  def ip_address_used_count_live(reload = false)
    @ip_address_used_count_live = nil if reload
    if @public
      # Number of ports with fixed IPs plugged into the network. Live means it talks directly to OpenStack API
      # TODO(lsmola) we probably need paginated API call, there should be no multitenancy needed, but the current
      # UI code allows to mix tenants, so it could be needed, athough netron doesn seem to have --all-tenants calls,
      # so when I use admin, I can see other tenant resources. Investigate, fix.
      @ip_address_used_count_live ||= ext_management_system.with_provider_connection(
        :service => "Network", :tenant_name => cloud_tenant.name) do |connection|
        connection.floating_ips.all(:floating_network_id => ems_ref).count
      end
    else
      @ip_address_used_count_live ||= ext_management_system.with_provider_connection(
        :service => "Network", :tenant_name => cloud_tenant.name) do |connection|
        connection.ports.all(:network_id => ems_ref, :device_owner => "compute:None").count
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
