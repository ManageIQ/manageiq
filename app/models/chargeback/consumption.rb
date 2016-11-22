class Chargeback
  class Consumption
    def initialize(metric_rollup_records, hours_in_interval)
      @rollups = metric_rollup_records
      @hours_in_interval = hours_in_interval
    end

    def max(metric)
      rollups_without_nils(metric).map(&metric.to_sym).max
    end

    def avg(metric)
      metric_sum = rollups_without_nils(metric).sum(&metric.to_sym)
      metric_sum / @hours_in_interval
    end

    def none?(metric)
      rollups_without_nils(metric).empty?
    end

    private

    def rollups_without_nils(metric)
      @rollups_without_nils ||= {}
      @rollups_without_nils[metric] ||= @rollups.select { |r| r.send(metric).present? }
    end
  end
end
