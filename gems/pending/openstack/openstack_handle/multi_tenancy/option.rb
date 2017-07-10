require 'openstack/openstack_handle/multi_tenancy/base'

module OpenstackHandle
  module MultiTenancy
    class Option < OpenstackHandle::MultiTenancy::Base
      def list
        @service.pagination_handle(@collection_type, @options.merge(:all_tenants => 'True'), @method).list
      end
    end
  end
end
