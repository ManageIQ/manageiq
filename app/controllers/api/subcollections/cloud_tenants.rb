module Api
  module Subcollections
    module CloudTenants
      def cloud_tenants_query_resource(object)
        object.respond_to?(:cloud_tenants) ? object.cloud_tenants : []
      end
    end
  end
end
