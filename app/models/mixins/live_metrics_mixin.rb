module LiveMetricsMixin
  extend ActiveSupport::Concern

  class MetricValidationError < RuntimeError; end

  included do
    def metrics_available
      raise 'LiveMetricsMixing: metrics_available missing'
    end

    def metric(_metric, _start_time, _end_time, _interval)
      raise 'LiveMetricsMixing: metric method missing'
    end

    def metrics(*metrics, start_time, end_time, interval)
      metrics = metrics_available if metrics.empty?
      processed = Hash.new { |h, k| h[k] = {} }
      metrics.each do |m|
        values = metric(m, start_time, end_time, interval)
        values.each do |k, a|
          processed[k].merge!(a)
        end
      end
      processed
    end
  end
end
