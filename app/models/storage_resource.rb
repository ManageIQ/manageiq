class StorageResource < ApplicationRecord
  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include AsyncDeleteMixin
  include AvailabilityMixin
  include SupportsFeatureMixin
  include CustomActionsMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ExtManagementSystem"
  belongs_to :storage_system, :foreign_key => :storage_system_id, :class_name => "StorageSystem"

  has_many :storage_services

  acts_as_miq_taggable

  def self.available
    # left_outer_joins(:attachments).where("disks.backing_id" => nil)
  end

  def self.class_by_ems(ext_management_system)
    # TODO(lsmola) taken from OrchesTration stacks, correct approach should be to have a factory on ExtManagementSystem
    # side, that would return correct class for each provider
    ext_management_system && ext_management_system.class::StorageResource
  end

  # Create a storage resource as a queued task and return the task id. The queue
  # name and the queue zone are derived from the provided EMS instance. The EMS
  # instance and a userid are mandatory. Any +options+ are forwarded as
  # arguments to the +create_volume+ method.
  #
  def self.create_storage_resource_queue(userid, ext_management_system, options = {})
    task_opts = {
      :action => "creating Cloud StorageResource for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => 'StorageResource',
      :method_name => 'create_storage_resource',
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_storage_resource(ems_id, options = {})
    raise ArgumentError, _("ems_id cannot be nil") if ems_id.nil?

    ext_management_system = ExtManagementSystem.find(ems_id)
    raise ArgumentError, _("ext_management_system cannot be found") if ext_management_system.nil?

    klass = class_by_ems(ext_management_system)
    klass.raw_create_storage_resource(ext_management_system, options)
  end

  def self.validate_create_storage_resource(ext_management_system)
    klass = class_by_ems(ext_management_system)
    return klass.validate_create_storage_resource(ext_management_system) if ext_management_system &&
                                                                            klass.respond_to?(:validate_create_storage_resource)

    validate_unsupported("Create StorageResource Operation")
  end

  def self.raw_create_storage_resource(_ext_management_system, _options = {})
    raise NotImplementedError, _("raw_create_storage_resource must be implemented in a subclass")
  end

  # Update a storage resource as a queued task and return the task id. The queue
  # name and the queue zone are derived from the EMS, and a userid is mandatory.
  #
  def update_storage_resource_queue(userid, options = {})
    task_opts = {
      :action => "updating StorageResource for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'update_storage_resource',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def update_storage_resource(options = {})
    raw_update_storage_resource(options)
  end

  def validate_update_storage_resource
    validate_unsupported("Update Volume Operation")
  end

  def raw_update_storage_resource(_options = {})
    raise NotImplementedError, _("raw_update_volume must be implemented in a subclass")
  end

  # Delete a storage resource as a queued task and return the task id. The queue
  # name and the queue zone are derived from the EMS, and a userid is mandatory.
  #
  def delete_storage_resource_queue(userid)
    task_opts = {
      :action => "deleting StorageResource for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_storage_resource',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => []
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def delete_storage_resource
    raw_delete_storage_resource
  end

  def validate_delete_storage_resource
    validate_unsupported("Delete StorageResource Operation")
  end

  def raw_delete_storage_resource
    raise NotImplementedError, _("raw_delete_storage_resource must be implemented in a subclass")
  end
end
