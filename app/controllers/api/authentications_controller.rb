module Api
  class AuthenticationsController < BaseController
    def delete_resource(type, id, _data = {})
      auth = resource_search(id, type, collection_class(:authentications))
      raise "Delete not supported for #{authentication_ident(auth)}" unless auth.respond_to?(:delete_in_provider_queue)
      task_id = auth.delete_in_provider_queue
      action_result(true, "Deleting #{authentication_ident(auth)}", :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    def options
      render_options(:authentications, :credential_types => build_additional_fields)
    end

    private

    def authentication_ident(auth)
      "Authentication id:#{auth.id} name: '#{auth.name}'"
    end

    def build_additional_fields
      ::Authentication.descendants.each_with_object({}) do |klass, fields|
        fields[klass.name] = klass::API_OPTIONS if defined? klass::API_OPTIONS
      end
    end
  end
end
