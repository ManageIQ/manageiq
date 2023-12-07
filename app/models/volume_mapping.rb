class VolumeMapping < ApplicationRecord
  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include SupportsFeatureMixin
  include CustomActionsMixin

  belongs_to :cloud_volume
  belongs_to :host_initiator
  belongs_to :host_initiator_group

  has_one :storage_resource, :through => :cloud_volume
  has_one :physical_storage, :through => :storage_resource

  belongs_to :ext_management_system, :foreign_key => :ems_id

  acts_as_miq_taggable

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def self.class_by_ems(ext_management_system)
    ext_management_system&.class_by_ems(:VolumeMapping)
  end

  def raw_delete_volume_mapping
    raise NotImplementedError, _("raw_delete_volume_mapping must be implemented in a subclass")
  end

  def delete_volume_mapping
    raw_delete_volume_mapping
  end

  # Delete a volume mapping as a queued task and return the task id. The queue
  # name and the queue zone are derived from the EMS, and a userid is mandatory.
  def delete_volume_mapping_queue(userid)
    task_opts = {
      :action => "deleting VolumeMapping for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_volume_mapping',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_volume_mapping_queue(userid, ext_management_system, options = {})
    task_opts = {
      :action => "creating VolumeMapping for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => 'VolumeMapping',
      :method_name => 'create_volume_mapping',
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_volume_mapping(ems_id, options = {})
    raise ArgumentError, _("ems_id cannot be nil") if ems_id.nil?

    ext_management_system = ExtManagementSystem.find_by(:id => ems_id)
    raise ArgumentError, _("ext_management_system cannot be found") if ext_management_system.nil?

    klass = ext_management_system.class_by_ems(:VolumeMapping)
    klass.raw_create_volume_mapping(ext_management_system, options)
  end

  def self.raw_create_volume_mapping(_ext_management_system, _options = {})
    raise NotImplementedError, _("raw_create_volume_mapping must be implemented in a subclass")
  end
end
