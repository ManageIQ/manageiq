module AnsiblePlaybookMixin
  extend ActiveSupport::Concern

  module ClassMethods
    private

    def create_job_template(name, description, info, auth_user)
      tower, params = build_parameter_list(name, description, info)

      task_id = ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ConfigurationScript.create_in_provider_queue(tower.id, params, auth_user)
      task = MiqTask.wait_for_taskid(task_id)
      raise task.message unless task.status == "Ok"
      [task.task_results, tower.id]
    end
  end
end
