class StorageService < ApplicationRecord
  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include SupportsFeatureMixin
  include CustomActionsMixin
  include EmsRefreshMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id,
                                     :class_name  => "ExtManagementSystem"
  has_many :storage_service_resource_attachments, :inverse_of => :storage_service, :dependent => :destroy
  has_many :storage_resources, :through => :storage_service_resource_attachments
  has_many :cloud_volumes

  acts_as_miq_taggable

  def self.class_by_ems(ext_management_system)
    ext_management_system&.class_by_ems(:StorageService)
  end

  def self.create_storage_service_queue(userid, ext_management_system, options = {})
    task_opts = {
      :action => "creating Storage Service for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => 'StorageService',
      :method_name => 'create_storage_service',
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_storage_service(ems_id, options = {})
    raise ArgumentError, _("ems_id cannot be nil") if ems_id.nil?

    ext_management_system = ExtManagementSystem.find_by(:id => ems_id)
    raise ArgumentError, _("ext_management_system cannot be found") if ext_management_system.nil?

    klass = ext_management_system.class_by_ems(:StorageService)
    klass.raw_create_storage_service(ext_management_system, options)
  end

  def self.raw_create_storage_service(_ext_management_system, _options = {})
    raise NotImplementedError, _("raw_create_storage_service must be implemented in a subclass")
  end

  def delete_storage_service_queue(userid)
    task_opts = {
      :action => "deleting Storage Service for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_storage_service',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def raw_delete_storage_service
    raise NotImplementedError, _("raw_delete_storage_service must be implemented in a subclass")
  end

  def delete_storage_service
    raw_delete_storage_service
  end

  def update_storage_service_queue(userid, options = {})
    task_opts = {
      :action => "updating Storage Service for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'update_storage_service',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def update_storage_service(options = {})
    raw_update_storage_service(options)
  end

  def raw_update_storage_service(_options = {})
    raise NotImplementedError, _("raw_update_storage_service must be implemented in a subclass")
  end

  def self.raw_check_compliant_resources(_ext_management_system, _options = {})
    raise NotImplementedError, _("raw_check_compliant_resources must be implemented in a subclass")
  end

  def self.check_compliant_resources(ems_id, options = {})
    raise ArgumentError, _("ems_id cannot be nil") if ems_id.nil?

    ext_management_system = ExtManagementSystem.find_by(:id => ems_id)
    raise ArgumentError, _("ext_management_system cannot be found") if ext_management_system.nil?

    klass = ext_management_system.class_by_ems(:StorageService)
    klass.raw_check_compliant_resources(ext_management_system, options)
  end

  def self.check_compliant_resources_queue(userid, ext_management_system, options = {})
    task_opts = {
      :action => "Checking resources compliance for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => 'StorageService',
      :method_name => 'check_compliant_resources',
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end
end
