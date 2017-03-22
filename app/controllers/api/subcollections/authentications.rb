module Api
  module Subcollections
    module Authentications
      def authentications_query_resource(object)
        object.respond_to?(:authentications) ? object.authentications : []
      end

      def authentications_create_resource(parent, _type, _id, data)
        task_id = AuthenticationService.create_authentication(parent.manager_id, data)
        action_result(true, 'Creating Authentication', :task_id => task_id)
      rescue => err
        action_result(false, err.to_s)
      end
    end
  end
end
