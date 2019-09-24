class CloudVolumeSnapshot < ApplicationRecord
  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include SupportsFeatureMixin
  include CloudTenancyMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ExtManagementSystem"
  belongs_to :cloud_tenant
  belongs_to :cloud_volume
  has_many   :based_volumes, :class_name => 'CloudVolume'

  virtual_total :total_based_volumes, :based_volumes

  def self.class_by_ems(ext_management_system)
    ext_management_system && ext_management_system.class::CloudVolumeSnapshot
  end

  def self.my_zone(ems)
    # TODO(pblaho): find unified way how to do that
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def my_zone
    self.class.my_zone(ext_management_system)
  end

  def delete_snapshot_queue(userid = "system", _options = {})
    task_opts = {
      :action => "deleting volume snapshot #{inspect} in #{ext_management_system.inspect}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => 'delete_snapshot',
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => my_zone,
      :args        => []
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def delete_snapshot
    raw_delete_snapshot
  rescue => e
    notification_options = {
      :snapshot_op => 'delete',
      :subject     => "[#{name}]",
      :error       => e.to_s
    }
    Notification.create(:type => :vm_snapshot_failure, :options => notification_options)

    raise e
  end

  def raw_delete_snapshot
    raise NotImplementedError, _("raw_delete_snapshot must be implemented in a subclass")
  end
end
