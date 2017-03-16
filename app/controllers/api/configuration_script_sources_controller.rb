module Api
  class ConfigurationScriptSourcesController < BaseController
    def edit_resource(type, id, data)
      config_script_src = resource_search(id, type, collection_class(:configuration_script_sources))
      raise "Update not supported for #{config_script_src_ident(config_script_src)}" unless config_script_src.respond_to?(:update_in_provider_queue)
      task_id = config_script_src.update_in_provider_queue(data)
      action_result(true, "Updating #{config_script_src_ident(config_script_src)}", :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def delete_resource(type, id, _data = {})
      config_script_src = resource_search(id, type, collection_class(:configuration_script_sources))
      raise "Delete not supported for #{config_script_src_ident(config_script_src)}" unless config_script_src.respond_to?(:delete_in_provider_queue)
      task_id = config_script_src.delete_in_provider_queue
      action_result(true, "Deleting #{config_script_src_ident(config_script_src)}", :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def create_resource(_type, _id, data)
      validate_attrs(data)
      manager_id = parse_id(data['manager_resource'], :providers)
      manager = resource_search(manager_id, :providers, collection_class(:providers))
      type = ConfigurationScriptSource.class_for_manager(manager)
      raise "ConfigurationScriptSource cannot be added to #{manager_ident(manager)}" unless type.respond_to?(:create_in_provider_queue)
      task_id = type.create_in_provider_queue(manager.id, data.except('manager_resource'))
      action_result(true, "Creating ConfigurationScriptSource for #{manager_ident(manager)}", :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    private

    def config_script_src_ident(config_script_src)
      "ConfigurationScriptSource id:#{config_script_src.id} name: '#{config_script_src.name}'"
    end

    def validate_attrs(data)
      raise 'must supply a manager resource' unless data['manager_resource']
    end

    def manager_ident(manager)
      "Manager id:#{manager.id} name: '#{manager.name}'"
    end
  end
end
