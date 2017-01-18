class Chargeback
  class RatesCache
    def get(consumption)
      # we need to select ChargebackRates for groups of MetricRollups records
      # and rates are selected by first MetricRollup record
      @rates ||= {}
      @rates[consumption.hash_features_affecting_rate] ||=
        ChargebackRate.get_assigned_for_target(consumption.resource,
                                               :tag_list => consumption.tag_list_with_prefix,
                                               :parents  => consumption.parents_determining_rate)
      if consumption.resource_type == Container.name && @rates[consumption.hash_features_affecting_rate].empty?
        @rates[consumption.hash_features_affecting_rate] = [ChargebackRate.find_by(
          :description => 'Default Container Image Rate', :rate_type => 'Compute')]
      end
      @rates[consumption.hash_features_affecting_rate]
    end
  end
end
