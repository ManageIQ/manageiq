class CloudVolumeBackup < ApplicationRecord
  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include SupportsFeatureMixin
  include CloudTenancyMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ExtManagementSystem"
  belongs_to :availability_zone
  belongs_to :cloud_volume
  has_one :cloud_tenant, :through => :cloud_volume

  # Restore a cloud volume backup as a queued task and return the task id. The queue
  # name and the queue zone are derived from the EMS. The userid is mandatory, and
  # the volumeid and name are optional.
  #
  def restore_queue(userid, volumeid = nil, name = nil)
    task_opts = {
      :action => "Restoring Cloud Volume Backup for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'restore',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [volumeid, name]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def restore(volume = nil, name = nil)
    raw_restore(volume, name)
  end

  def raw_restore(*)
    raise NotImplementedError, _("raw_restore must be implemented in a subclass")
  end

  # Delete a cloud volume backup as a queued task and return the task id. The queue
  # name and the queue zone are derived from the EMS, and a userid is mandatory.
  #
  def delete_queue(userid)
    task_opts = {
      :action => "deleting Cloud Volume Backup for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => []
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def delete
    raw_delete
  end

  def raw_delete
    raise NotImplementedError, _("raw_delete must be implemented in a subclass")
  end
end
