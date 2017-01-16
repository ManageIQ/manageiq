class Chargeback
  class ConsumptionHistory
    VIRTUAL_COL_USES = {
      'v_derived_cpu_total_cores_used' => 'cpu_usage_rate_average'
    }.freeze

    def self.for_report(cb_class, options)
      base_rollup = base_rollup_scope
      timerange = options.report_time_range
      interval_duration = options.duration_of_report_step

      extra_resources = cb_class.try(:extra_resources_without_rollups) || []
      timerange.step_value(interval_duration).each_cons(2) do |query_start_time, query_end_time|
        extra_resources.each do |resource|
          consumption = ConsumptionWithoutRollups.new(resource, query_start_time, query_end_time)
          yield(consumption) unless consumption.consumed_hours_in_interval.zero?
        end

        records = base_rollup.where(:timestamp => query_start_time...query_end_time, :capture_interval_name => 'hourly')
        records = cb_class.where_clause(records, options)
        records = Metric::Helper.remove_duplicate_timestamps(records)
        next if records.empty?
        _log.info("Found #{records.length} records for time range #{[query_start_time, query_end_time].inspect}")

        # we are building hash with grouped calculated values
        # values are grouped by resource_id and timestamp (query_start_time...query_end_time)
        records.group_by(&:resource_id).each do |_, metric_rollup_records|
          metric_rollup_records = metric_rollup_records.select { |x| x.resource.present? }
          consumption = ConsumptionWithRollups.new(metric_rollup_records, query_start_time, query_end_time)
          next if metric_rollup_records.empty?
          yield(consumption)
        end
      end
    end

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
    private_class_method :base_rollup_scope
  end
end
