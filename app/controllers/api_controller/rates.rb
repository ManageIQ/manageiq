class ApiController
  module Rates
    #
    # Rates Subcollection Supporting Methods
    #
    def rates_query_resource(object)
      object.send("chargeback_rate_details")
    end
  end
end
