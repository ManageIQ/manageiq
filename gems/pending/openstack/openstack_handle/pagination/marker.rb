require 'openstack/openstack_handle/pagination/base'

module OpenstackHandle
  module Pagination
    class Marker < OpenstackHandle::Pagination::Base
      def list
        all_objects = objects_on_page = call_list_method(@collection_type, @options, @method)

        while more_pages?(objects_on_page)
          objects_on_page = call_list_method(@collection_type,
                                             @options,
                                             @method,
                                             :marker => marker(objects_on_page),
                                             :limit  => @service.default_pagination_limit)
          break if pagination_break?(all_objects, objects_on_page)
          all_objects.concat(objects_on_page)
        end

        all_objects
      end

      private

      def more_pages?(objects_on_page)
        marker(objects_on_page) && @service.more_pages?(objects_on_page)
      end

      def marker(objects_on_page)
        objects_on_page.try(:last).try(:identity)
      end

      def pagination_break?(all_objects, objects_on_page)
        # Test if the whole set of records isn't already present, if it is, break the pagination.
        # E.g. Neutron can have disabled pagination like this, then it just returns the same result and pagination
        # would loop forever.
        all_objects.blank? || objects_on_page.blank? || repeated_objects?(all_objects, objects_on_page)
      end

      def repeated_objects?(all_objects, objects_on_page)
        objects_on_page.try(:last).try(:identity) == all_objects.try(:last).try(:identity)
      end
    end
  end
end
