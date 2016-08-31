module Api
  module Subcollections
    module Software
      def software_query_resource(object)
        object.guest_applications
      end
    end
  end
end
