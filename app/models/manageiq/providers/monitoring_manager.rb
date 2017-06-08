module ManageIQ::Providers
  class MonitoringManager < BaseManager
    class << model_name
      def route_key
        "ems_monitoring"
      end

      def singular_route_key
        "ems_monitoring"
      end
    end
  end
end
