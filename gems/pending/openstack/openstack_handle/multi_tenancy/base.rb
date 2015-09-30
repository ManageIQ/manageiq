module OpenstackHandle
  module MultiTenancy
    class Base
      def initialize(service, os_handle, service_name, collection_type, options = {}, method = :all)
        @service            = service
        @os_handle          = os_handle
        @service_name       = service_name
        @collection_type    = collection_type
        @options            = options
        @method             = method
      end
    end
  end
end
