module Api
  module Subcollections
    module Events
      def events_query_resource(object)
        return {} unless object.respond_to?(:events)
        object.events
      end
    end
  end
end
