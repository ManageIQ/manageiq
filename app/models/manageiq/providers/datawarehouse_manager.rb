module ManageIQ::Providers
  class DatawarehouseManager < BaseManager
    class << model_name
      def route_key
        "ems_datawarehouse"
      end

      def singular_route_key
        "ems_datawarehouse"
      end
    end
  end
end
