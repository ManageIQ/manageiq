module Api
  module Subcollections
    module Authentications
      def authentications_query_resource(object)
        object.respond_to?(:authentications) ? object.authentications : []
      end

      def authentications_create_resource(parent, _type, _id, data)
        klass = ::Authentication.class_from_request_data(data)
        raise 'type not currently supported' unless klass.respond_to?(:create_in_provider_queue)
        task_id = klass.create_in_provider_queue(parent.manager_id, data.except('type'))
        action_result(true, 'Creating Authentication', :task_id => task_id)
      rescue => err
        action_result(false, err.to_s)
      end
    end
  end
end
