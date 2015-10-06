module OpenstackHandle
  module Pagination
    class Base
      def initialize(service, os_handle, collection_type, options = {}, method = :all)
        @service         = service
        @os_handle       = os_handle
        @collection_type = collection_type
        @options         = options
        @method          = method
      end

      private

      def call_list_method(collection_type, options, method, paginate_options = {})
        options = {:limit => @service.default_pagination_limit}.merge(options).merge(paginate_options)
        if @service.public_send(collection_type).respond_to?(method)
          # In the case when we call a model method
          @service.public_send(collection_type).public_send(method, options)
        else
          # In the case when we want to call request method directly, e.g. list_detailed_snapshots, but
          # this is a hacky solution, so it's only temporary, before all objects will be defined in a fog
          # as a proper models.
          # We need to send index of the data in the request body
          request_body_index = options.delete(:__request_body_index)
          @service.public_send(collection_type, options).body[request_body_index]
        end
      end
    end
  end
end
