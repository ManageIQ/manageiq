module Api
  class ServiceRequestsController < BaseController
    include Subcollections::RequestTasks
    include Subcollections::Tasks

    def approve_resource(type, id, data)
      raise "Must specify a reason for approving a service request" unless data["reason"].present?
      api_action(type, id) do |klass|
        provreq = resource_search(id, type, klass)
        provreq.approve(@auth_user, data['reason'])
        action_result(true, "Service request #{id} approved")
      end
    rescue => err
      action_result(false, err.to_s)
    end

    def deny_resource(type, id, data)
      raise "Must specify a reason for denying a service request" unless data["reason"].present?
      api_action(type, id) do |klass|
        provreq = resource_search(id, type, klass)
        provreq.deny(@auth_user, data['reason'])
        action_result(true, "Service request #{id} denied")
      end
    rescue => err
      action_result(false, err.to_s)
    end

    def edit_resource(type, id, data)
      request = resource_search(id, type, collection_class(:service_requests))
      request_options = RequestParser.parse_options(data)
      user = RequestParser.parse_user(data) || User.current_user
      request.update_request(request_options, user)
    rescue => err
      raise BadRequestError, "Could not update the service request - #{err}"
    end

    def find_service_requests(id)
      klass = collection_class(:service_requests)
      return klass.find(id) if User.current_user.admin?
      klass.find_by!(:requester => User.current_user, :id => id)
    end

    def service_requests_search_conditions
      return {} if User.current_user.admin?
      {:requester => User.current_user}
    end

    def get_user(data)
      user_id = data['user_id'] || parse_id(data['user'], :users)
      raise 'Must specify a valid user_id or user' unless user_id
      User.find(user_id)
    end

    def add_approver_resource(type, id, data)
      user = get_user(data)
      miq_approval = MiqApproval.create(:approver => user)
      resource_search(id, type, collection_class(:service_requests)).tap do |service_request|
        service_request.miq_approvals << miq_approval
      end
    rescue => err
      raise BadRequestError, "Cannot add approver - #{err}"
    end

    def remove_approver_resource(type, id, data)
      user = get_user(data)
      resource_search(id, type, collection_class(:service_requests)).tap do |service_request|
        miq_approval = service_request.miq_approvals.find_by(:approver_name => user.name)
        miq_approval.destroy if miq_approval
      end
    rescue => err
      raise BadRequestError, "Cannot remove approver - #{err}"
    end
  end
end
