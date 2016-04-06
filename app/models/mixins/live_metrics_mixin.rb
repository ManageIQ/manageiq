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

    def first_and_last_capture(interval_name = "realtime")
      firsts, lasts = metrics_capture.metrics_available.collect do |metric| #
        metrics_capture.first_and_last_capture(metric)
      end.transpose
      adjust_timestamps(firsts, lasts, interval_name)
    rescue => e
      _log.error("Hawkular service unavailable: #{e.message}")
      return [nil, nil]
    end

    def adjust_timestamps(firsts, lasts, interval_name)
      first = Time.at(firsts.min / 1000).utc
      last = Time.at(lasts.max / 1000).utc
      now = Time.new.utc
      if interval_name == "hourly"
        first = (now - first) > 1.hour ? first : nil
      end
      [first, last]
    end
  end
end
