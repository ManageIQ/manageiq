module Api
  class ServiceOrdersController < BaseController
    include Subcollections::ServiceRequests
    USER_CART_ID = 'cart'.freeze

    def create_resource(type, id, data)
      raise BadRequestError, "Can't create an ordered service order" if data["state"] == ServiceOrder::STATE_ORDERED
      service_requests = data.delete("service_requests")
      data["state"] ||= ServiceOrder::STATE_CART
      if service_requests.blank?
        super
      else
        create_service_order_with_service_requests(service_requests)
        ServiceOrder.cart_for(User.current_user)
      end
    end

    def clear_resource(type, id, _data)
      service_order = resource_search(id, type, collection_class(type))
      begin
        service_order.clear
      rescue => e
        raise BadRequestError, e.message
      end
      service_order
    end

    def order_resource(type, id, _data)
      service_order = resource_search(id, type, collection_class(type))
      service_order.checkout
      service_order
    end

    def validate_id(id, klass)
      id == USER_CART_ID || super(id, klass)
    end

    def find_service_orders(id)
      if id == USER_CART_ID
        ServiceOrder.cart_for(User.current_user)
      else
        ServiceOrder.find_for_user(User.current_user, id)
      end
    end

    def service_orders_search_conditions
      {:user => User.current_user, :tenant => User.current_user.current_tenant}
    end

    def copy_resource(type, id, data)
      service_order = resource_search(id, type, collection_class(type))
      service_order.deep_copy(data)
    rescue => err
      raise BadRequestError, "Could not copy service order - #{err}"
    end

    private

    def add_request_to_cart(workflow)
      workflow.add_request_to_cart
    end

    def create_service_order_with_service_requests(service_requests)
      workflows = validate_service_requests(service_requests)
      workflows.each do |workflow|
        check_validation(add_request_to_cart(workflow))
      end
    end

    def validate_service_requests(service_requests)
      service_requests.collect do |service_request|
        workflow = service_request_workflow(service_request)
        check_validation(workflow.validate_dialog)
        workflow
      end
    end

    def service_request_workflow(service_request)
      service_template_id = href_id(service_request.delete("service_template_href"), :service_templates)
      if service_template_id.blank?
        raise BadRequestError, "Must specify a service_template_href for adding a service_request"
      end
      service_template = resource_search(service_template_id, :service_templates, ServiceTemplate)
      ServiceTemplateWorkflow.create(service_template, service_request)
    end

    def check_validation(validation)
      if validation[:errors].present?
        raise BadRequestError, "Invalid service request - #{validation[:errors].join(", ")}"
      end
    end
  end
end
