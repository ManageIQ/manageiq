module Api
  module Subcollections
    module LoadBalancers
      def load_balancers_query_resource(object)
        object.respond_to?(:load_balancers) ? object.load_balancers : []
      end
    end
  end
end
