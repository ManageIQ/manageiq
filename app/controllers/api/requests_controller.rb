module Api
  class RequestsController < BaseController
    include Subcollections::RequestTasks
    include Subcollections::Tasks

    def create_resource(type, _id, data)
      assert_id_not_specified(data, type)

      request_type = data.delete("request_type")
      validate_request_type(request_type)

      if data["src_id"].blank? && data["src_ids"].blank?
        raise BadRequestError, "Must specify a resource src_id or src_ids"
      end

      user = parse_requester_user(data.delete("requester"))
      auto_approve = parse_auto_approve(data.delete("auto_approve"))

      request_type.constantize.create_request(data.symbolize_keys, user, auto_approve)
    end

    def edit_resource(type, id = nil, data = {})
      raise BadRequestError, "Must specify a id for editing a #{type} resource" unless id
      request_klass = collection_class(:requests)
      request = resource_search(id, type, request_klass)
      user = parse_requester_user(data.delete("requester"))

      request_klass.update_request(request, data, user)
      request
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

    def validate_request_type(request_type)
      raise BadRequestError, "Must specify a request_type" if request_type.blank?
      unless MiqRequest::REQUEST_TYPES.stringify_keys.keys.include?(request_type)
        raise BadRequestError, "Invalid Request Type #{request_type} specified"
      end
    end

    def parse_requester_user(requester)
      user_name = Hash(requester)["user_name"]
      return @auth_user_obj if user_name.blank?
      user = User.lookup_by_identity(user_name)
      raise BadRequestError, "Unknown requester user_name #{user_name} specified" unless user
      user
    end

    def parse_auto_approve(auto_approve)
      case auto_approve
      when TrueClass, "true" then true
      when FalseClass, "false", nil then false
      else raise BadRequestError, "Invalid requester auto_approve value #{auto_approve} specified"
      end
    end
  end
end
