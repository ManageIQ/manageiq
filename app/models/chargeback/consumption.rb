class Chargeback
  class Consumption
    attr_reader :hours_in_interval

    def initialize(metric_rollup_records, hours_in_interval)
      @rollups = metric_rollup_records
      @hours_in_interval = hours_in_interval
    end

    def max(metric)
      values(metric).max
    end

    def avg(metric)
      metric_sum = values(metric).sum
      metric_sum / @hours_in_interval
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
  end
end
