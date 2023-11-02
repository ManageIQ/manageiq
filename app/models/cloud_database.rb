class CloudDatabase < ApplicationRecord
  include AsyncDeleteMixin
  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include SupportsFeatureMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  belongs_to :cloud_tenant
  belongs_to :cloud_database_flavor
  belongs_to :resource_group
  belongs_to :cloud_database_server

  serialize :extra_attributes

  def self.create_cloud_database_queue(userid, ext_management_system, options = {})
    task_opts = {
      :action => "creating Cloud Database for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => name,
      :method_name => 'create_cloud_database',
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_cloud_database(ems_id, options = {})
    raise ArgumentError, _("ems_id cannot be nil") if ems_id.nil?

    ext_management_system = ExtManagementSystem.find(ems_id)
    klass = ext_management_system.class_by_ems(:CloudDatabase)
    klass.raw_create_cloud_database(ext_management_system, options)
  end

  def self.raw_create_cloud_database(_ext_management_system, _options = {})
    raise NotImplementedError, _("raw_create_cloud_database must be implemented in a subclass")
  end

  def delete_cloud_database_queue(userid)
    task_opts = {
      :action => "deleting Cloud Database for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_cloud_database',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => []
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def delete_cloud_database
    raw_delete_cloud_database
  end

  def raw_delete_cloud_database
    raise NotImplementedError, _("raw_delete_cloud_database must be implemented in a subclass")
  end

  def update_cloud_database_queue(userid, options = {})
    task_opts = {
      :action => "updating Cloud Database for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'update_cloud_database',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def update_cloud_database(options = {})
    raw_update_cloud_database(options)
  end

  def raw_update_cloud_database(_options = {})
    raise NotImplementedError, _("raw_update_cloud_database must be implemented in a subclass")
  end
end
