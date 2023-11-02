class CloudVolumeSnapshot < ApplicationRecord
  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include SupportsFeatureMixin
  include CloudTenancyMixin
  include CustomActionsMixin
  include EmsRefreshMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ExtManagementSystem"
  belongs_to :cloud_tenant
  belongs_to :cloud_volume
  has_many   :based_volumes, :class_name => 'CloudVolume'

  virtual_total :total_based_volumes, :based_volumes

  def self.class_by_ems(ext_management_system)
    ext_management_system&.class_by_ems(:CloudVolumeSnapshot)
  end

  def self.my_zone(ems)
    # TODO(pblaho): find unified way how to do that
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def my_zone
    self.class.my_zone(ext_management_system)
  end

  def self.create_snapshot_queue(userid, cloud_volume, options = {})
    raise ArgumentError, "Must provide a cloud volume with a provider" if cloud_volume&.ext_management_system.nil?

    ext_management_system = cloud_volume.ext_management_system
    task_opts = {
      :action => "creating volume snapshot in #{ext_management_system.inspect} for #{cloud_volume.inspect} with #{options.inspect}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => name,
      :method_name => 'create_snapshot',
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => my_zone(ext_management_system),
      :args        => [cloud_volume.id, options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_snapshot(cloud_volume_id, options)
    cloud_volume = CloudVolume.find(cloud_volume_id)
    raw_create_snapshot(cloud_volume, options)
  end

  def self.raw_create_snapshot(_cloud_volume, _options)
    raise NotImplementedError, _("raw_create_snapshot must be implemented in a subclass")
  end

  def update_snapshot_queue(userid = "system", options = {})
    task_opts = {
      :action => "updating volume snapshot #{inspect} in #{ext_management_system.inspect} with #{options.inspect}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => 'update_snapshot',
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => my_zone,
      :args        => [options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def update_snapshot(options = {})
    raw_update_snapshot(options)
  end

  def raw_update_snapshot(_options = {})
    raise NotImplementedError, _("update_snapshot must be implemented in a subclass")
  end

  # Delete a cloud volume snapshot as a queued task and return the task id. The
  # queue name and the queue zone are derived from the EMS. The userid is
  # optional and defaults to 'system'.
  #
  # The _options argument is unused, and is strictly for interface compliance.
  #
  def delete_snapshot_queue(userid = "system", _options = {})
    task_opts = {
      :action => "deleting volume snapshot for #{userid} in #{ext_management_system.name}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => 'delete_snapshot',
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
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
