class ApiController
  module Rates
    #
    # Rates Subcollection Supporting Methods
    #
    def rates_query_resource(object)
      object.send("chargeback_rate_details")
    end

    def create_resource_rates(_type, _id, data = {})
      ChargebackRateDetail.create(data)
    end
  end
end
