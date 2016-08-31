module Api
  module Subcollections
    module Schedules
      def schedules_query_resource(object)
        object ? object.list_schedules : {}
      end
    end
  end
end
