module Api
  module Subcollections
    module ServiceRequests
      def service_requests_query_resource(object)
        return {} unless object
        klass = collection_class(:service_requests)

        case object
        when collection_class(:service_orders)
          klass.where(:service_order_id => object.id)
        else
          klass.where(:source_id => object.id)
        end
      end

      def service_requests_add_resource(target, _type, _id, data)
        result = add_service_request(target, data)
        add_parent_href_to_result(result)
        log_result(result)
        result
      end

      def service_requests_remove_resource(target, type, id, _data)
        service_request_subcollection_action(type, id) do |service_request|
          api_log_info("Removing #{service_request_ident(service_request)}")
          remove_service_request(target, service_request)
        end
      end

      private

      def service_request_ident(service_request)
        "Service Request id:#{service_request.id} description:'#{service_request.description}'"
      end

      def service_request_subcollection_action(type, id)
        klass = collection_class(:service_requests)
        result =
          begin
            service_request = resource_search(id, type, klass)
            yield(service_request) if block_given?
          rescue => e
            action_result(false, e.to_s)
          end
        add_subcollection_resource_to_result(result, type, service_request) if service_request
        add_parent_href_to_result(result)
        log_result(result)
        result
      end

      def add_service_request(target, data)
        if target.state != ServiceOrder::STATE_CART
          raise BadRequestError, "Must specify a cart to add a service request to"
        end
        workflow = service_request_workflow(data)
        validation = add_request_to_cart(workflow)
        if validation[:errors].present?
          action_result(false, validation[:errors].join(", "))
        elsif validation[:request].nil?
          action_result(false, "Unable to add service request")
        else
          result = action_result(true, "Adding service_request")
          add_subcollection_resource_to_result(result, :service_requests, validation[:request])
          result
        end
      rescue => e
        action_result(false, e.to_s)
      end

      def remove_service_request(target, service_request)
        target.class.remove_from_cart(service_request, User.current_user)
        action_result(true, "Removing #{service_request_ident(service_request)}")
      rescue => e
        action_result(false, e.to_s)
      end
    end
  end
end
