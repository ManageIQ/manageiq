class ApiController
  module ServiceOrders
    def create_resource_service_orders(type, id, data)
      raise BadRequestError, "Can't create an ordered service order" if data["state"] == ServiceOrder::STATE_ORDERED
      service_requests = data.delete("service_requests")
      data["state"] ||= ServiceOrder::STATE_CART
      if service_requests.blank?
        create_resource(type, id, data)
      else
        create_service_order_with_service_requests(service_requests)
        ServiceOrder.cart_for(@auth_user_obj)
      end
    end

    def clear_resource_service_orders(type, id, _data)
      service_order = resource_search(id, type, collection_class(type))
      begin
        service_order.clear
      rescue => e
        raise BadRequestError, e.message
      end
      service_order
    end

    def order_resource_service_orders(type, id, _data)
      service_order = resource_search(id, type, collection_class(type))
      service_order.checkout
      service_order
    end

    def find_service_orders(id)
      if id == "cart"
        ServiceOrder.cart_for(@auth_user_obj)
      else
        ServiceOrder.find_for_user(@auth_user_obj, id)
      end
    end

    def service_orders_search_conditions
      {:user => @auth_user_obj, :tenant => @auth_user_obj.current_tenant}
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
      service_template_workflow(service_template, service_request)
    end

    def service_template_workflow(service_template, service_request)
      resource_action = service_template.resource_actions.find_by_action("Provision")
      workflow = ResourceActionWorkflow.new({}, @auth_user_obj, resource_action, :target => service_template)
      service_request.each { |key, value| workflow.set_value(key, value) } if service_request.present?
      workflow
    end

    def check_validation(validation)
      if validation[:errors].present?
        raise BadRequestError, "Invalid service request - #{validation[:errors].join(", ")}"
      end
    end
  end
end
