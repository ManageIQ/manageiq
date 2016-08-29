module Api
  class BaseController
    module Accounts
      #
      # Accounts Subcollection Supporting Methods
      #
      def accounts_query_resource(object)
        object.accounts
      end
    end
  end
end
