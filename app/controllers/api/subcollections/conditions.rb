module Api
  module Subcollections
    module Conditions
      def conditions_query_resource(object)
        return {} unless object.respond_to?(:conditions)
        object.conditions
      end
    end
  end
end
