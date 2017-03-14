module Api
  class ConfigurationScriptSourcesController < BaseController
    def edit_resource(type, id, data)
      config_script_src = resource_search(id, type, collection_class(:configuration_script_sources))
      task_id = config_script_src.update_in_provider_queue(data)
      action_result(true, "Updating Configuration Script Source with id #{id}", :task_id => task_id)
    rescue => err
      raise "Could not update Configuration Script Source - #{err}"
    end

    def delete_resource(type, id, _data = {})
      config_script_src = resource_search(id, type, collection_class(:configuration_script_sources))
      task_id = config_script_src.delete_in_provider_queue
      action_result(true, "Deleting Configuration Script Source with id #{id}", :task_id => task_id)
    rescue => err
      raise "Could not delete Configuration Script Source - #{err}"
    end
  end
end
