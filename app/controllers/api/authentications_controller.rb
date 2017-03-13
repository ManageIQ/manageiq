module Api
  class AuthenticationsController < BaseController
    def delete_resource(type, id, _data = {})
      auth = resource_search(id, type, collection_class(:authentications))
      task_id = auth.delete_in_provider_queue
      action_result(true, "Deleting Authentication with id #{id}", :task_id => task_id)
    rescue => err
      raise "Could not delete authentication - #{err}"
    end
  end
end
