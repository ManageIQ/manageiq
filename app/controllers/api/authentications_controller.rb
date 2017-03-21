module Api
  class AuthenticationsController < BaseController
    def edit_resource(type, id, data)
      auth = resource_search(id, type, collection_class(:authentications))
      raise "Update not supported for #{authentication_ident(auth)}" unless auth.respond_to?(:update_in_provider_queue)
      task_id = auth.update_in_provider_queue(data)
      action_result(true, "Updating #{authentication_ident(auth)}", :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def create_resource(_type, _id, data)
      attrs = validate_auth_attrs(data)
      klass = ::Authentication.class_from_request_data(attrs)
      # TODO: Temporary validation - remove
      raise 'type not currently supported' unless klass.respond_to?(:create_in_provider_queue)
      task_id = klass.create_in_provider_queue(attrs['manager_resource'], attrs.except('type', 'manager_resource'))
      action_result(true, 'Creating Authentication', :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def delete_resource(type, id, _data = {})
      auth = resource_search(id, type, collection_class(:authentications))
      raise "Delete not supported for #{authentication_ident(auth)}" unless auth.respond_to?(:delete_in_provider_queue)
      task_id = auth.delete_in_provider_queue
      action_result(true, "Deleting #{authentication_ident(auth)}", :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def options
      render_options(:authentications, build_additional_fields)
    end

    private

    def authentication_ident(auth)
      "Authentication id:#{auth.id} name: '#{auth.name}'"
    end

    def build_additional_fields
      {
        :credential_types => ::Authentication.build_credential_options
      }
    end

    def validate_auth_attrs(data)
      raise 'must supply a manager resource' unless data['manager_resource']
      attrs = data.dup
      collection, id = parse_href(data['manager_resource']['href'])
      raise "#{collection} is not a valid manager resource" unless ::Authentication::MANAGER_TYPES.include?(collection)
      attrs['manager_resource'] = id
      attrs
    end
  end
end
