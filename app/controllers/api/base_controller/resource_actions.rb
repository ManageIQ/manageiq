module Api
  class BaseController
    module ResourceActions
      #
      # Resource Actions Subcollection Supporting Methods
      #
      def resource_actions_query_resource(object)
        object.resource_actions
      end
    end
  end
end
