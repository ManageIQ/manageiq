module ManageIQ
  module API
    class ApiController
      module CloudNetworks
        def cloud_networks_query_resource(object)
          object.cloud_networks
        end
      end
    end
  end
end
