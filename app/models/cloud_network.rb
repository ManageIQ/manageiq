class CloudNetwork < ApplicationRecord
  include NewWithTypeStiMixin
  include SupportsFeatureMixin
  include CloudTenancyMixin
  include CustomActionsMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
  belongs_to :cloud_tenant
  belongs_to :orchestration_stack
  belongs_to :resource_group

  has_many :cloud_subnets, :dependent => :destroy
  has_many :network_routers, -> { distinct }, :through => :cloud_subnets
  has_many :public_networks, -> { distinct }, :through => :cloud_subnets
  has_many :network_ports, -> { distinct }, :through => :cloud_subnets
  has_many :floating_ips,  :dependent => :destroy
  has_many :vms, -> { distinct }, :through => :network_ports, :source => :device, :source_type => 'VmOrTemplate'

  has_many :public_network_routers, :foreign_key => :cloud_network_id, :class_name => "NetworkRouter"
  has_many :public_network_vms, -> { distinct }, :through => :public_network_routers, :source => :vms
  has_many :private_networks, -> { distinct }, :through => :public_network_routers, :source => :cloud_networks

  # TODO(lsmola) figure out what this means, like security groups used by VMs in the network? It's not being
  # refreshed, so we can probably delete this association
  has_many   :security_groups
  has_many :firewall_rules, :as => :resource, :dependent => :destroy

  # Use for virtual columns, mainly for modeling array and hash types, we get from the API
  serialize :extra_attributes

  virtual_column :maximum_transmission_unit, :type => :string
  virtual_column :port_security_enabled,     :type => :string
  virtual_column :qos_policy_id,             :type => :string

  # Define all getters and setters for extra_attributes related virtual columns
  %i[maximum_transmission_unit port_security_enabled qos_policy_id].each do |action|
    define_method(:"#{action}=") do |value|
      extra_attributes_save(action, value)
    end

    define_method(action) do
      extra_attributes_load(action)
    end
  end

  virtual_total :total_vms, :vms

  def self.class_by_ems(ext_management_system, _external = false)
    ext_management_system&.class_by_ems(:CloudNetwork)
  end

  def self.tenant_id_clause_format(tenant_ids)
    ["((tenants.id IN (?) OR cloud_networks.shared IS TRUE OR cloud_networks.external_facing IS TRUE) AND ext_management_systems.tenant_mapping_enabled IS TRUE) OR ext_management_systems.tenant_mapping_enabled IS FALSE OR ext_management_systems.tenant_mapping_enabled IS NULL", tenant_ids]
  end

  def update_cloud_network_queue(userid, options = {})
    task_opts = {
      :action => "updating Cloud Network for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'update_cloud_network',
      :instance_id => id,
      :priority    => MiqQueue::NORMAL_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def update_cloud_network(options = {})
    raw_update_cloud_network(options)
  end

  def raw_update_cloud_network(_options = {})
    raise NotImplementedError, _("raw_update_cloud_network must be implemented in a subclass")
  end

  def delete_cloud_network_queue(userid, options = {})
    task_opts = {
      :action => "deleting Cloud Network for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_cloud_network',
      :instance_id => id,
      :priority    => MiqQueue::NORMAL_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def delete_cloud_network(options)
    raw_delete_cloud_network(options)
  end

  def raw_delete_cloud_network(_options)
    raise NotImplementedError, _("raw_delete_cloud_network must be implemented in a subclass")
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
