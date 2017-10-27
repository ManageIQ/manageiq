class Chargeback
  class ConsumptionWithRollups < Consumption
    delegate :timestamp, :resource, :resource_id, :resource_name, :resource_type, :parent_ems,
             :hash_features_affecting_rate, :tag_list_with_prefix, :parents_determining_rate,
             :to => :first_metric_rollup_record

    attr_accessor :start_time, :end_time

    def initialize(metric_rollup_records, start_time, end_time)
      super(start_time, end_time)
      @rollups = metric_rollup_records
    end

    def tag_names
      first_metric_rollup_record.tag_names.split('|')
    end

    def max(metric, sub_metric = nil)
      values(metric, sub_metric).max
    end

    def avg(metric, sub_metric = nil)
      metric_sum = values(metric, sub_metric).sum
      metric_sum / consumed_hours_in_interval
    end

    def none?(metric)
      values(metric).empty?
    end

    def chargeback_fields_present
      @chargeback_fields_present ||= @rollups.count(&:chargeback_fields_present?)
    end

    private

    def born_at
      # metrics can be older than resource (first capture may go few days back)
      [super, first_metric_rollup_record.timestamp].compact.min
    end

    def sub_metric_rollups(sub_metric)
      q = VimPerformanceState.where(:timestamp => start_time...end_time, :resource => resource, :capture_interval => 3_600)
      q.map { |x| x.allocated_disk_types[sub_metric] || 0 }
    end

    def values(metric, sub_metric = nil)
      @values ||= {}
      @values["#{metric}#{sub_metric}"] ||= sub_metric ? sub_metric_rollups(sub_metric) : @rollups.collect(&metric.to_sym).compact
    end

    def first_metric_rollup_record
      @fmrr ||= @rollups.first
    end
  end
end
