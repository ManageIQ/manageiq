module Api
  module Subcollections
    module Authentications
      def authentications_query_resource(object)
        object.respond_to?(:authentications) ? object.authentications : []
      end

      def authentications_create_resource(parent, _type, _id, data)
        klass = ::Authentication.class_from_request_data(data)
        raise 'type not currently supported' unless klass.respond_to?(:create_in_provider_queue)
        klass.create_in_provider_queue(parent.manager_id, data.except('type'))
      rescue => err
        raise BadRequestError, "Cannot create Authentication - #{err}"
      end
    end
  end
end
