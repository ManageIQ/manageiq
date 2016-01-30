require 'openstack/openstack_handle/pagination/base'

module OpenstackHandle
  module Pagination
    class None < OpenstackHandle::Pagination::Base
      def list
        call_list_method(@collection_type, @options, @method)
      end
    end
  end
end
