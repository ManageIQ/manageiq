class CloudObjectStoreContainer < ApplicationRecord
  include CloudTenancyMixin
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ExtManagementSystem"
  belongs_to :cloud_tenant
  has_many   :cloud_object_store_objects

  acts_as_miq_taggable

  include ProviderObjectMixin
  include NewWithTypeStiMixin
  include ProcessTasksMixin
  include SupportsFeatureMixin
  include CustomActionsMixin

  include Operations

  alias_attribute :name, :key

  # Create a cloud object store container as a queued task and return the task
  # id. The queue name and the queue zone are derived from the provided EMS
  # instance. The EMS instance and a userid are mandatory. Any +options+ are
  # forwarded as arguments to the +cloud_object_store_container_create+ method.
  #
  def self.cloud_object_store_container_create_queue(userid, ext_management_system, options = {})
    task_opts = {
      :action => "creating Cloud Object Store Container for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => 'CloudObjectStoreContainer',
      :method_name => 'cloud_object_store_container_create',
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.cloud_object_store_container_create(ems_id, options)
    raise ArgumentError, _("ems_id cannot be nil") if ems_id.nil?

    ext_management_system = ExtManagementSystem.find(ems_id)
    raise ArgumentError, _("ext_management_system cannot be found") if ext_management_system.nil?

    klass = ext_management_system.class::CloudObjectStoreContainer
    created_container = klass.raw_cloud_object_store_container_create(ext_management_system, options)

    klass.create(created_container)
  end

  def self.raw_cloud_object_store_container_create(_ext_management_system, _options)
    raise NotImplementedError, _("must be implemented in subclass")
  end

  def cloud_object_store_container_delete_queue(userid)
    task_opts = {
      :action => "deleting Cloud Object Store Container for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => 'CloudObjectStoreContainer',
      :method_name => 'cloud_object_store_container_delete',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => []
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.display_name(number = 1)
    n_('Cloud Object Store Container', 'Cloud Object Store Containers', number)
  end
end
