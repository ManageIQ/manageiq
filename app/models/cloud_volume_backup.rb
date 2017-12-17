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

  def restore_queue(userid, volumeid)
    task_opts = {
      :action => "Restoring Cloud Volume Backup for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'restore',
      :instance_id => id,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [volumeid]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def restore(volume)
    raw_restore(volume)
  end

  def raw_restore(*)
    raise NotImplementedError, _("raw_restore must be implemented in a subclass")
  end

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
