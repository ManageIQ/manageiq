class Chargeback
  class RatesCache
    def initialize(options = nil)
      @options = options
    end

    def get(consumption)
      # we need to select ChargebackRates for groups of MetricRollups records
      # and rates are selected by first MetricRollup record
      @rates ||= {}
      @rates[consumption.hash_features_affecting_rate] ||= rates(consumption)
    end

    def currency_for_report
      @currency_for_report ||=
        begin
          # A very problematic way to get currency info when formatting a chargeback report.
          # The only right way is to carry currency info. TBD.
          rate = ChargebackRate.get_assignments(:compute)[0] || ChargebackRate.get_assignments(:storage)[0]
          rate[:cb_rate].currency_symbol unless rate.nil?
        end
    end

    private

    def rates(consumption)
      rates = ChargebackRate.get_assigned_for_target(consumption.resource,
                                                     :tag_list => consumption.tag_list_with_prefix,
                                                     :parents  => consumption.parents_determining_rate)

      if consumption.resource.kind_of?(Container) && rates.empty?
        rates = [ChargebackRate.find_by(:description => "Default Container Image Rate", :rate_type => "Compute")]
      end

      metric_rollup_record_tags = consumption.tag_names

      @options.cumulative_rate_calculation? ? rates.sort_by(&:description) : unique_rates_by_tagged_resources(rates, metric_rollup_record_tags)
    end

    def unique_rates_by_tagged_resources(rates, metric_rollup_record_tags)
      grouped_rates = rates.group_by(&:rate_type)

      compute_rates = select_rate_by_tags(grouped_rates["Compute"] || [], metric_rollup_record_tags)
      storage_rates = select_rate_by_tags(grouped_rates["Storage"] || [], metric_rollup_record_tags)

      [compute_rates, storage_rates].flatten
    end

    def select_rate_by_tags(rates, metric_rollup_record_tags)
      return rates if rates.empty? || rates.count == 1
      return rates unless rates.all?(&:assigned_tags?) # Are rates assigned to tagged resources ?

      rates.sort_by(&:description).detect { |rate| (rate.assigned_tags & metric_rollup_record_tags).present? }
    end
  end
end
