class HostAggregate < ApplicationRecord
  include SupportsFeatureMixin
  include NewWithTypeStiMixin
  include Metric::CiMixin
  include EventMixin
  include ProviderObjectMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"

  has_many   :host_aggregate_hosts, :dependent => :destroy
  has_many   :hosts,             :through => :host_aggregate_hosts
  has_many   :vms,               :through => :hosts
  has_many   :vms_and_templates, :through => :hosts
  has_many   :metrics,                :as => :resource
  has_many   :metric_rollups,         :as => :resource
  has_many   :vim_performance_states, :as => :resource

  virtual_total :total_vms, :vms

  def self.create_aggregate_queue(userid, ext_management_system, options = {})
    task_opts = {
      :action => "creating Host Aggregate for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => ext_management_system.class.class_by_ems("HostAggregate"),
      :method_name => 'create_aggregate',
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_aggregate(*_args)
    raise NotImplementedError, _("create_aggregate must be implemented in a subclass")
  end

  def update_aggregate_queue(userid, options = {})
    task_opts = {
      :action => "updating Host Aggregate for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'update_aggregate',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def update_aggregate(*_args)
    raise NotImplementedError, _("update_aggregate must be implemented in a subclass")
  end

  def delete_aggregate_queue(userid)
    task_opts = {
      :action => "deleting Host Aggregate for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_aggregate',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def delete_aggregate(*_args)
    raise NotImplementedError, _("delete_aggregate must be implemented in a subclass")
  end

  def add_host_queue(userid, new_host)
    task_opts = {
      :action => "Adding Host to Host Aggregate for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'add_host',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [new_host.id]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def add_host(*_args)
    raise NotImplementedError, _("add_host must be implemented in a subclass")
  end

  def remove_host_queue(userid, old_host)
    task_opts = {
      :action => "Removing Host from Host Aggregate for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'remove_host',
      :instance_id => id,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [old_host.id]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def remove_host(*_args)
    raise NotImplementedError, _("remove_host must be implemented in a subclass")
  end

  PERF_ROLLUP_CHILDREN = [:vms]

  def perf_rollup_parents(_interval_name = nil)
    # don't rollup to ext_management_system since that's handled through availability zone
    nil
  end

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end
end
