class ApiController
  module Chargebacks

    def rates_query_resource(object)
      klass = collection_config[:rates][:klass].constantize
      object ? klass.where(:chargeback_rate_id => object.id) : {}
    end

  end
end
