class SecurityPolicyRule < ApplicationRecord
  include NewWithTypeStiMixin
  include SupportsFeatureMixin
  include CloudTenancyMixin
  include CustomActionsMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
  belongs_to :cloud_tenant
  belongs_to :orchestration_stack
  belongs_to :security_policy

  has_many :security_policy_rule_source_security_groups, :dependent => :destroy
  has_many :source_security_groups, :through => :security_policy_rule_source_security_groups, :source => :security_group
  has_many :source_vms, -> { distinct }, :through => :source_security_groups, :source => :vms

  has_many :security_policy_rule_destination_security_groups, :dependent => :destroy
  has_many :destination_security_groups, :through => :security_policy_rule_destination_security_groups, :source => :security_group
  has_many :destination_vms, -> { distinct }, :through => :destination_security_groups, :source => :vms

  has_many :security_policy_rule_network_services, :dependent => :destroy
  has_many :network_services, :through => :security_policy_rule_network_services

  virtual_total :source_security_groups_count, :source_security_groups
  virtual_total :destination_security_groups_count, :destination_security_groups
  virtual_total :network_services_count, :network_services

  def self.class_by_ems(ext_management_system)
    # TODO: use a factory on ExtManagementSystem side to return correct class for each provider
    ext_management_system && ext_management_system.class::SecurityPolicyRule
  end

  def update_security_policy_rule_queue(userid, options = {})
    task_opts = {
      :action => "updating Security Policy Rule for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'update_security_policy_rule',
      :instance_id => id,
      :priority    => MiqQueue::NORMAL_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def update_security_policy_rule(options = {})
    raw_update_security_policy_rule(options)
  end

  def raw_update_security_policy_rule(_options = {})
    raise NotImplementedError, _("raw_update_security_policy_rule must be implemented in a subclass")
  end

  def delete_security_policy_rule_queue(userid, options = {})
    task_opts = {
      :action => "deleting Security Policy Rule for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_security_policy_rule',
      :instance_id => id,
      :priority    => MiqQueue::NORMAL_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def delete_security_policy_rule(options)
    raw_delete_security_policy_rule(options)
  end

  def raw_delete_security_policy_rule(_options)
    raise NotImplementedError, _("raw_delete_security_policy_rule must be implemented in a subclass")
  end

  def self.display_name(number = 1)
    n_('Security Policy Rule', 'Security Policy Rules', number)
  end
end
