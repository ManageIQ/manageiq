module Api
  module Subcollections
    module CloudNetworks
      def cloud_networks_query_resource(object)
        object.respond_to?(:cloud_networks) ? object.cloud_networks : []
      end
    end
  end
end
