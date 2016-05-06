class ApiController
  module ServiceOrders
    def find_service_orders(id)
      ServiceOrder.find_for_user(@auth_user_obj, id)
    end

    def service_orders_search_conditions
      {:user => @auth_user_obj, :tenant => @auth_user_obj.current_tenant}
    end
  end
end
