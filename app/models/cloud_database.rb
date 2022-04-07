class CloudDatabase < ApplicationRecord
  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include SupportsFeatureMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager"
  belongs_to :cloud_tenant
  belongs_to :cloud_database_flavor
  belongs_to :resource_group

  serialize :extra_attributes

  supports_not :delete

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
end
