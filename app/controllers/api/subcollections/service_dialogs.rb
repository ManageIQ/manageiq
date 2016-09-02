module Api
  module Subcollections
    module ServiceDialogs
      def service_dialogs_query_resource(object)
        object ? object.dialogs : []
      end
    end
  end
end
