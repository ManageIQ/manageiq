module Api
  class AuthenticationsController < BaseController
    def edit_resource(type, id, data)
      auth = resource_search(id, type, collection_class(:authentications))
      task_id = auth.update_in_provider_queue(data)
      action_result(true, "Updating Authentication with id #{id}", :task_id => task_id)
    rescue => err
      raise "Could not update Authentication - #{err}"
    end

    def delete_resource(type, id, _data = {})
      auth = resource_search(id, type, collection_class(:authentications))
      raise "Delete not supported for #{authentication_ident(auth)}" unless auth.respond_to?(:delete_in_provider_queue)
      task_id = auth.delete_in_provider_queue
      action_result(true, "Deleting #{authentication_ident(auth)}", :task_id => task_id)
    rescue => err
      action_result(false, err.to_s)
    end

    private

    def authentication_ident(auth)
      "Authentication id:#{auth.id} name: '#{auth.name}'"
    end
  end
end
