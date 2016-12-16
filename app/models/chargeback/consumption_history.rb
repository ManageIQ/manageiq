class Chargeback
  class ConsumptionHistory
    VIRTUAL_COL_USES = {
      'v_derived_cpu_total_cores_used' => 'cpu_usage_rate_average'
    }.freeze

    def self.base_rollup_scope
      base_rollup = MetricRollup.includes(
        :resource           => [:hardware, :tenant, :tags, :vim_performance_states, :custom_attributes,
                                {:container_image => :custom_attributes}],
        :parent_host        => :tags,
        :parent_ems_cluster => :tags,
        :parent_storage     => :tags,
        :parent_ems         => :tags)
                                .select(*Metric::BASE_COLS).order('resource_id, timestamp')

      perf_cols = MetricRollup.attribute_names
      rate_cols = ChargebackRate.where(:default => true).flat_map do |rate|
        rate.chargeback_rate_details.map(&:metric).select { |metric| perf_cols.include?(metric.to_s) }
      end
      rate_cols.map! { |x| VIRTUAL_COL_USES[x] || x }.flatten!
      base_rollup.select(*rate_cols)
    end
  end
end
