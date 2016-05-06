class ApiController
  module ServiceOrders
    def create_resource_service_orders(type, id, data)
      raise BadRequestError, "Can't create an ordered service order" if data["state"] == ServiceOrder::STATE_ORDERED
      create_resource(type, id, data)
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
  end
end
