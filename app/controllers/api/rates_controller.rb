module Api
  class RatesController < BaseController
    def create_resource(_type, _id, data = {})
      rate_detail = ChargebackRateDetail.create(data)
      raise BadRequestError, rate_detail.errors.full_messages.join(', ') unless rate_detail.valid?
      rate_detail
    end
  end
end
