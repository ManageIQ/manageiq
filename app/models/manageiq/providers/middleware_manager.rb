module ManageIQ::Providers
  class MiddlewareManager < BaseManager
    class << model_name
      def route_key
        "ems_middleware"
      end

      def singular_route_key
        "ems_middleware"
      end
    end
  end
end
