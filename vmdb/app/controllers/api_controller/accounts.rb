class ApiController
  module Accounts
    #
    # Accounts Subcollection Supporting Methods
    #
    def accounts_query_resource(object)
      object.send("accounts")
    end
  end
end
