require 'openstack/openstack_handle/multi_tenancy/base'

module OpenstackHandle
  module MultiTenancy
    class None < OpenstackHandle::MultiTenancy::Base
      def list
        @service.pagination_handle(@collection_type, @options, @method)
      end
    end
  end
end
