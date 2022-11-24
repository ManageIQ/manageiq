class PhysicalServerProfileTemplate < ApplicationRecord
  acts_as_miq_taggable

  include NewWithTypeStiMixin
  include TenantIdentityMixin
  include SupportsFeatureMixin
  include ProviderObjectMixin
  include EmsRefreshMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :physical_server_profile_templates,
    :class_name => "ManageIQ::Providers::PhysicalInfraManager"

  delegate :queue_name_for_ems_operations, :to => :ext_management_system, :allow_nil => true

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def deploy_server_from_template_queue(server_id, profile_name)
    task_opts = {
      :action => "Deploy server from profile template",
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'deploy_server_from_template',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [server_id, profile_name]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end
end
