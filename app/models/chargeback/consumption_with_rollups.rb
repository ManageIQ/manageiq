class Chargeback
  class ConsumptionWithRollups < Consumption
    delegate :timestamp, :resource, :resource_id, :resource_name, :resource_type, :parent_ems,
             :hash_features_affecting_rate, :tag_list_with_prefix, :parents_determining_rate,
             :to => :first_metric_rollup_record

    def initialize(metric_rollup_records, start_time, end_time)
      super(start_time, end_time)
      @rollups = metric_rollup_records
    end

    def tag_names
      first_metric_rollup_record.tag_names.split('|')
    end

    def max(metric)
      values(metric).max
    end

    def avg(metric)
      metric_sum = values(metric).sum
      metric_sum / consumed_hours_in_interval
    end

    def none?(metric)
      values(metric).empty?
    end

    def chargeback_fields_present
      @chargeback_fields_present ||= @rollups.count(&:chargeback_fields_present?)
    end

    private

    def values(metric)
      @values ||= {}
      @values[metric] ||= @rollups.collect(&metric.to_sym).compact
    end

    def first_metric_rollup_record
      @fmrr ||= @rollups.first
    end
  end
end
