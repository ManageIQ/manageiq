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
      attrs = validate_attrs(data)
      type = ConfigurationScriptSource.class_from_request_data(attrs)
      raise 'type not currently supported' unless type.respond_to?(:create_in_provider_queue)
      task_id = type.create_in_provider_queue(attrs['manager_resource'], attrs.except('manager_resource'))
      action_result(true, 'Creating ConfigurationScriptSource', :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    private

    def config_script_src_ident(config_script_src)
      "ConfigurationScriptSource id:#{config_script_src.id} name: '#{config_script_src.name}'"
    end

    def validate_attrs(data)
      raise 'must supply a manager resource' unless data['manager_resource']
      attrs = data.dup
      attrs['manager_resource'] = if data['manager_resource'].key?('href')
                                    parse_href(data['manager_resource']['href']).last
                                  elsif data['manager_resource'].key?('id')
                                    data['manager_resource']['id']
                                  end
      attrs
    end
  end
end
