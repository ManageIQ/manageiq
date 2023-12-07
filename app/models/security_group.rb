class SecurityGroup < ApplicationRecord
  include NewWithTypeStiMixin
  include SupportsFeatureMixin
  include CloudTenancyMixin
  include CustomActionsMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
  belongs_to :cloud_network
  belongs_to :cloud_tenant
  belongs_to :orchestration_stack
  belongs_to :network_group
  belongs_to :cloud_subnet
  belongs_to :network_router
  belongs_to :resource_group
  has_many   :firewall_rules, :as => :resource, :dependent => :destroy

  has_many :network_port_security_groups, :dependent => :destroy
  has_many :network_ports, :through => :network_port_security_groups
  # TODO(lsmola) we should be able to remove table security_groups_vms, if it's unused now. Can't be backported
  has_many :vms, -> { distinct }, :through => :network_ports, :source => :device, :source_type => 'VmOrTemplate'
  has_many :security_policy_rule_source_security_groups, :dependent => :destroy
  has_many :security_policy_rules_as_source, :through => :security_policy_rule_source_security_groups, :source => :security_policy_rule
  has_many :security_policy_rule_destination_security_groups, :dependent => :destroy
  has_many :security_policy_rules_as_destination, :through => :security_policy_rule_destination_security_groups, :source => :security_policy_rule

  virtual_total :total_vms, :vms
  virtual_total :total_security_policy_rules_as_source, :security_policy_rules_as_source, :uses => :security_policy_rules_as_source
  virtual_total :total_security_policy_rules_as_destination, :security_policy_rules_as_destination, :uses => :security_policy_rules_as_destination

  def self.non_cloud_network
    where(:cloud_network_id => nil)
  end

  def self.class_by_ems(ext_management_system)
    ext_management_system&.class_by_ems(:SecurityGroup)
  end

  def update_security_group_queue(userid, options = {})
    task_opts = {
      :action => "updating Security Group for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'update_security_group',
      :instance_id => id,
      :priority    => MiqQueue::NORMAL_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def update_security_group(options = {})
    raw_update_security_group(options)
  end

  def raw_update_security_group(_options = {})
    raise NotImplementedError, _("raw_update_security_group must be implemented in a subclass")
  end

  def delete_security_group_queue(userid, options = {})
    task_opts = {
      :action => "deleting Security Group for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_security_group',
      :instance_id => id,
      :priority    => MiqQueue::NORMAL_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def delete_security_group(options)
    raw_delete_security_group(options)
  end

  def raw_delete_security_group(_options)
    raise NotImplementedError, _("raw_delete_security_group must be implemented in a subclass")
  end
end
