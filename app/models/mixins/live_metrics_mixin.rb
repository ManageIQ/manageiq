module LiveMetricsMixin
  extend ActiveSupport::Concern

  class MetricValidationError < RuntimeError; end

  included do
    def collect_live_metrics(metrics, start_time, end_time, interval)
      processed = Hash.new { |h, k| h[k] = {} }
      metrics.each do |metric|
        values = collect_live_metric(metric, start_time, end_time, interval)
        processed.merge!(values) { |_k, old, new| old.merge(new) }
      end
      processed
    end
  end
end
