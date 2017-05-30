module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::ConfigurationScript
  extend ActiveSupport::Concern

  module ClassMethods
    NAME_MAP = {
      'create' => 'Creating',
      'update' => 'Updating',
      'delete' => 'Deleting'
    }.freeze
    private_constant :NAME_MAP

    def create_in_provider(manager_id, params)
      manager = ExtManagementSystem.find(manager_id)
      job_template = manager.with_provider_connection do |connection|
        connection.api.job_templates.create!(params)
      end

      # Get the record in our database
      # TODO: This needs to be targeted refresh so it doesn't take too long
      task_ids = EmsRefresh.queue_refresh_task(manager)
      task_ids.each { |tid| MiqTask.wait_for_taskid(tid) }

      find_by!(:manager_id => manager.id, :manager_ref => job_template.id)
    rescue AnsibleTowerClient::Error => err
      begin
        raise err.class, JSON.parse(err.message).values.flatten.join(", ")
      rescue JSON::ParserError
        raise err
      end
    end

    def update_in_provider(manager_id, params)
      manager = ExtManagementSystem.find(manager_id)
      manager.with_provider_connection do |connection|
        connection.api.job_templates.find(params.delete(:manager_ref)).update_attributes!(params)
      end

      # Get the record in our database
      # TODO: This needs to be targeted refresh so it doesn't take too long
      EmsRefresh.queue_refresh(manager)
    end

    def delete_in_provider(manager_id, params)
      manager = ExtManagementSystem.find(manager_id)
      manager.with_provider_connection do |connection|
        if params[:name]
          connection.api.job_templates.all(:search => params[:name]).first.destroy!
        else
          connection.api.job_templates.find(params[:manager_ref]).destroy!
        end
      end

      # Get the record in our database
      # TODO: This needs to be targeted refresh so it doesn't take too long
      EmsRefresh.queue_refresh(manager)
    end

    def delete_in_provider_queue(manager_id, params, auth_user = nil)
      operate_in_provider_queue('delete', manager_id, params, auth_user)
    end

    def update_in_provider_queue(manager_id, params, auth_user = nil)
      operate_in_provider_queue('update', manager_id, params, auth_user)
    end

    def create_in_provider_queue(manager_id, params, auth_user = nil)
      operate_in_provider_queue('create', manager_id, params, auth_user)
    end

    private

    def operate_in_provider_queue(action, manager_id, params, auth_user)
      manager = ExtManagementSystem.find(manager_id)

      task_opts = {
        :action => "#{NAME_MAP[action]} Ansible Tower Job Template",
        :userid => auth_user || "system"
      }
      queue_opts = {
        :args        => [manager_id, params],
        :class_name  => self.name,
        :method_name => "#{action}_in_provider",
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
