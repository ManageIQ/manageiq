module Api
  class AutomationRequestsController < BaseController
    include Subcollections::RequestTasks
    include Subcollections::Tasks

    def create_resource(type, _id, data)
      assert_id_not_specified(data, type)

      version_str = data["version"] || "1.1"
      uri_parts   = hash_fetch(data, "uri_parts")
      parameters  = hash_fetch(data, "parameters")
      requester   = hash_fetch(data, "requester")

      AutomationRequest.create_from_ws(version_str, User.current_user, uri_parts, parameters, requester)
    end

    def approve_resource(type, id, data)
      raise "Must specify a reason for approving an automation request" unless data["reason"].present?
      api_action(type, id) do |klass|
        request = resource_search(id, type, klass)
        request.approve(@auth_user, data["reason"])
        action_result(true, "Automation request #{id} approved")
      end
    rescue => err
      action_result(false, err.to_s)
    end

    def deny_resource(type, id, data)
      raise "Must specify a reason for denying an automation request" unless data["reason"].present?
      api_action(type, id) do |klass|
        request = resource_search(id, type, klass)
        request.deny(@auth_user, data["reason"])
        action_result(true, "Automation request #{id} denied")
      end
    rescue => err
      action_result(false, err.to_s)
    end
  end
end
