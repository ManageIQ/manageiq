class Chargeback
  class ConsumptionHistory
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

        next unless options.include_metrics?

        records = base_rollup.where(:timestamp => query_start_time...query_end_time, :capture_interval_name => 'hourly')
        records = cb_class.where_clause(records, options)
        records = Metric::Helper.remove_duplicate_timestamps(records)
        next if records.empty?
        _log.info("Found #{records.length} records for time range #{[query_start_time, query_end_time].inspect}")

        # we are building hash with grouped calculated values
        # values are grouped by resource_id and timestamp (query_start_time...query_end_time)
        records.group_by(&:resource_id).each do |_, metric_rollup_records|
          consumption = ConsumptionWithRollups.new(metric_rollup_records, query_start_time, query_end_time)
          yield(consumption) unless consumption.consumed_hours_in_interval.zero?
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

      base_rollup.select(*ChargeableField.chargeable_cols_on_metric_rollup).with_resource
    end

    private_class_method :base_rollup_scope
  end
end
