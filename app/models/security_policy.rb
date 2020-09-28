class SecurityPolicy < ApplicationRecord
  include NewWithTypeStiMixin
  include SupportsFeatureMixin
  include CloudTenancyMixin
  include CustomActionsMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
  belongs_to :cloud_tenant
  belongs_to :orchestration_stack

  has_many :security_policy_rules, :foreign_key => :security_policy_id, :dependent => :destroy
  alias rules security_policy_rules

  virtual_total :rules_count, :rules

  def self.class_by_ems(ext_management_system)
    # TODO: use a factory on ExtManagementSystem side to return correct class for each provider
    ext_management_system && ext_management_system.class::SecurityPolicy
  end

  def update_security_policy_queue(userid, options = {})
    task_opts = {
      :action => "updating Security Policy for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'update_security_policy',
      :instance_id => id,
      :priority    => MiqQueue::NORMAL_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def update_security_policy(options)
    raw_update_security_policy(options)
  end

  def raw_update_security_policy(_options = {})
    raise NotImplementedError, _("raw_update_security_policy must be implemented in a subclass")
  end

  def delete_security_policy_queue(userid, options = {})
    task_opts = {
      :action => "deleting Security Policy for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_security_policy',
      :instance_id => id,
      :priority    => MiqQueue::NORMAL_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def delete_security_policy(options)
    raw_delete_security_policy(options)
  end

  def raw_delete_security_policy(_options)
    raise NotImplementedError, _("raw_delete_security_policy must be implemented in a subclass")
  end

  def self.display_name(number = 1)
    n_('Security Policy', 'Security Policies', number)
  end
end
