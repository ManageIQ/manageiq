class Chargeback
  class ConsumptionHistory
    def self.for_report(cb_class, options, region)
      timerange = options.report_time_range
      interval_duration = options.duration_of_report_step

      extra_resources = cb_class.try(:extra_resources_without_rollups, region) || []
      timerange.step_value(interval_duration).each_cons(2) do |query_start_time, query_end_time|
        extra_resources.each do |resource|
          _log.info("Using ConsumptionWithoutRollups for resource #{resource.id} #{resource.class} for time range #{[query_start_time, query_end_time].inspect}")
          consumption = ConsumptionWithoutRollups.new(resource, query_start_time, query_end_time)
          _log.info("Consumed Hours for ConsumptionWithoutRollups: #{consumption.consumed_hours_in_interval}")
          yield(consumption) unless consumption.consumed_hours_in_interval.zero?
        end

        next unless options.include_metrics?

        records = MetricRollup.where(:timestamp => query_start_time...query_end_time, :capture_interval_name => 'hourly')
        records = cb_class.where_clause(records, options, region)
        records = uniq_timestamp_record_map(records, options.group_by_tenant?)

        next if records.empty?
        _log.info("Found #{records.flatten.flatten.count - records.keys.count} records for time range #{[query_start_time, query_end_time].inspect}")

        # we are building hash with grouped calculated values
        # values are grouped by resource_id and timestamp (query_start_time...query_end_time)
        records.each_value do |rollup_record_ids|
          metric_rollup_records = MetricRollup.where(:id => rollup_record_ids).order(:resource_type, :resource_id, :timestamp).pluck(*ChargeableField.cols_on_metric_rollup)
          _log.debug("Count of Metric Rollups for consumption: #{metric_rollup_records.count}")
          consumption = ConsumptionWithRollups.new(metric_rollup_records, query_start_time, query_end_time)
          yield(consumption) unless consumption.consumed_hours_in_interval.zero?
        end
      end
    end

    def self.base_rollup_scope
      MetricRollup.select(*(Metric::BASE_COLS + ChargeableField.chargeable_cols_on_metric_rollup))
    end

    private_class_method :base_rollup_scope

    def self.uniq_timestamp_record_map(report_scope, group_by_tenant = false)
      metric_columns = ChargeableField.chargeable_cols_on_metric_rollup.map { |column| "MAX(#{column}) OVER (PARTITION BY timestamp, resource_type, resource_id) as #{column}" }
      partition_statements = metric_columns.join(', ')

      partition_query = <<-SQL
        metric_rollups.id, metric_rollups.tag_names, metric_rollups.resource_id, metric_rollups.timestamp, metric_rollups.resource_type, #{partition_statements}
      SQL

      metric_rollup_scope = report_scope.with_resource.select(partition_query).order(:resource_type, :resource_id, :timestamp).order("created_on DESC")

      distinct_query = "SELECT DISTINCT rows.#{ChargeableField.cols_on_metric_rollup.join(', rows.')} FROM (#{metric_rollup_scope.to_sql}) as rows"

      rows = ActiveRecord::Base.connection.select_rows(distinct_query)

      if group_by_tenant
        # third is id of VM
        vm_ids_with_tenant_ids = Hash[Vm.where(:id => rows.map(&:third)).pluck(:id, :tenant_id)]
      end

      rows.each_with_object({}) do |(id, tag_names, resource_id, *row), result|
        group_by_id = resource_id
        group_by_id = vm_ids_with_tenant_ids[resource_id] if group_by_tenant
        result[group_by_id] ||= []
        result[group_by_id] << ([id, tag_names, resource_id] + row)
      end
    end

    private_class_method :uniq_timestamp_record_map
  end
end
