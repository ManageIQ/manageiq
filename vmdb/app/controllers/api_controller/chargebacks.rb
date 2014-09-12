class ApiController
  module Chargebacks

    def rates_query_resource(object)
      klass = collection_config[:rates][:klass].constantize
      object ? klass.where(:chargaback_rate_id => object.id) : {}
    end

    #def update_chargebacks()
      #api_log_info("here")
      #render json: {}
    #end

    #def set_chargeback()
    #end

    #def get_assignments(type)
      #ChargebackRate.get_assignments(type)
    #end

    #def build_rates_obj()
      #rates = []
      #cbrs = ChargebackRate.all()
      #cbrs.each do |cbr|
        #rate = cbr.attributes
        #rate['rate_details'] = cbr.chargeback_rate_details
        #rates.append(rate)
      #end
      #rates
    #end

    #def show_chargebacks()
      #render json: {
        #:rates => build_rates_obj(),
        #:assignments => {
          #:compute => get_assignments(:compute),
          #:storage => get_assignments(:storage)
        #}
      #}
    #end
  end
end
