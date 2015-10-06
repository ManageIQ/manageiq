require 'openstack/openstack_handle/multi_tenancy/base'

module OpenstackHandle
  module MultiTenancy
    class Loop < OpenstackHandle::MultiTenancy::Base
      def list
        paginated_list_method = -> (x) { x.pagination_handle(@collection_type, @options, @method).list }
        @os_handle.accessor_for_accessible_tenants(@service_name,
                                                   paginated_list_method,
                                                   nil)
      end
    end
  end
end
