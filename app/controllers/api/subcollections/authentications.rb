module Api
  module Subcollections
    module Authentications
      def authentications_query_resource(object)
        object.respond_to?(:authentications) ? object.authentications : []
      end
    end
  end
end
