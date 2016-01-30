require 'openstack/openstack_handle/pagination/base'

module OpenstackHandle
  module Pagination
    class PageNumber < OpenstackHandle::Pagination::Base
      def list
        # TBD, used e.g. by keystone v3
      end
    end
  end
end
