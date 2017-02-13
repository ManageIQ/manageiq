module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::ConfigurationScript
  extend ActiveSupport::Concern

  module ClassMethods

    def create_in_provider(manager_id, params)
      manager = ExtManagementSystem.find(manager_id)
      job_template = manager.with_provider_connection do |connection|
        connection.api.job_templates.create!(params)
      end

      # Get the record in our database
      # TODO: This needs to be targeted refresh so it doesn't take too long
      EmsRefresh.queue_refresh(manager, nil, true) if !manager.missing_credentials? && manager.authentication_status_ok?
      find_by(:manager_id => manager.id, :manager_ref => job_template.id)
    end

    def create_in_provider_queue(manager_id, params, auth_user = nil)
      manager = ExtManagementSystem.find(manager_id)
      task_opts = {
        :action => "Creating Ansible Tower Job Template",
        :userid => auth_user || "system"
      }
      queue_opts = {
        :args        => [manager_id, params],
        :class_name  => self.name,
        :method_name => "create_in_provider",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :role        => "ems_operations",
        :zone        => manager.my_zone
      }

      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end
  end

  def run(vars = {})
    options = vars.merge(merge_extra_vars(vars[:extra_vars]))

    with_provider_object do |jt|
      jt.launch(options)
    end
  end

  def merge_extra_vars(external)
    {:extra_vars => variables.merge(external || {}).to_json}
  end

  def provider_object(connection = nil)
    (connection || connection_source.connect).api.job_templates.find(manager_ref)
  end
end
