class Chargeback
  class RatesCache
    def get(consumption)
      # we need to select ChargebackRates for groups of MetricRollups records
      # and rates are selected by first MetricRollup record
      perf = consumption.first_metric_rollup_record
      @rates ||= {}
      @rates[perf.hash_features_affecting_rate] ||= rates(perf)
    end

    private

    def rates(metric_rollup_record)
      rates = ChargebackRate.get_assigned_for_target(metric_rollup_record.resource,
                                                     :tag_list => metric_rollup_record.tag_list_with_prefix,
                                                     :parents  => metric_rollup_record.parents_determining_rate)

      if metric_rollup_record.resource_type == Container.name && rates.empty?
        rates = [ChargebackRate.find_by(:description => "Default Container Image Rate", :rate_type => "Compute")]
      end

      metric_rollup_record_tags = metric_rollup_record.tag_names.split("|")

      unique_rates_by_tagged_resources(rates, metric_rollup_record_tags)
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
