class ApiController
  module ServiceCatalogs
    #
    # Support service catalog creation with no action, straight
    # post being "create" in addition of "add" for keeping v1.0 compatibility.
    #
    # Simply leveraging the generic add_resource method.
    #
    def create_resource_service_catalogs(type, id, data = {})
      add_resource(type, id, data)
    end
  end
end
