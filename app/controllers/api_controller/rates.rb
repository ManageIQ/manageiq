class ApiController
  module Rates
    #
    # Rates Subcollection Supporting Methods
    #
    def rates_query_resource(object)
      object.chargeback_rate_details
    end

    def create_resource_rates(_type, _id, data = {})
      rate_detail = ChargebackRateDetail.create(data)
      raise BadRequestError, "#{rate_detail.errors.full_messages.join(', ')}" unless rate_detail.valid?
      rate_detail
    end
  end
end
