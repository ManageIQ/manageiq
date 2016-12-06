module Api
  class RequestsController < BaseController
    include Subcollections::RequestTasks
    include Subcollections::Tasks

    def create_resource(type, _id, data)
      assert_id_not_specified(data, type)
      request_klass = collection_class(:requests)
      request_options = RequestParser.parse_options(data)

      begin
        typed_request_klass = request_klass.class_from_request_data(request_options)
      rescue => err
        raise BadRequestError, "Invalid request - #{err}"
      end

      # We must authorize the user based on the request type klass
      authorize_request(typed_request_klass)

      user = RequestParser.parse_user(data) || @auth_user_obj
      auto_approve = RequestParser.parse_auto_approve(data)

      begin
        typed_request_klass.create_request(request_options, user, auto_approve)
      rescue => err
        raise BadRequestError, "Could not create the request - #{err}"
      end
    end

    def edit_resource(type, id = nil, data = {})
      raise BadRequestError, "Must specify a id for editing a #{type} resource" unless id
      request_klass = collection_class(:requests)
      request = resource_search(id, type, request_klass)

      request_options = RequestParser.parse_options(data)
      user = RequestParser.parse_user(data) || @auth_user_obj

      begin
        request.update_request(request_options, user)
      rescue => err
        raise BadRequestError, "Could not update the request - #{err}"
      end

      request
    end

    def approve_resource(type, id, data)
      raise "Must specify a reason for approving a request" if data["reason"].blank?
      api_action(type, id) do |klass|
        request = resource_search(id, type, klass)
        request.approve(@auth_user, data["reason"])
        action_result(true, "Request #{id} approved")
      end
    rescue => err
      action_result(false, err.to_s)
    end

    def deny_resource(type, id, data)
      raise "Must specify a reason for denying a request" if data["reason"].blank?
      api_action(type, id) do |klass|
        request = resource_search(id, type, klass)
        request.deny(@auth_user, data["reason"])
        action_result(true, "Request #{id} denied")
      end
    rescue => err
      action_result(false, err.to_s)
    end

    def find_requests(id)
      klass = collection_class(:requests)
      return klass.find(id) if @auth_user_obj.admin?
      klass.find_by!(:requester => @auth_user_obj, :id => id)
    end

    def requests_search_conditions
      return {} if @auth_user_obj.admin?
      {:requester => @auth_user_obj}
    end

    private

    def authorize_request(typed_request_klass)
      create_action = collection_config["requests"].collection_actions.post.detect { |a| a.name == "create" }
      request_spec = create_action.identifiers.detect { |i| i.klass == typed_request_klass.name }
      raise BadRequestError, "Unsupported request class #{typed_request_klass}" if request_spec.blank?

      if request_spec.identifier && !api_user_role_allows?(request_spec.identifier)
        raise ForbiddenError, "Create action is forbidden for #{typed_request_klass} requests"
      end
    end
  end
end
