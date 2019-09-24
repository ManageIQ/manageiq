module LiveMetricsMixin
  extend ActiveSupport::Concern

  LIVE_METRICS_DIR = Rails.root.join("product/live_metrics")

  class MetricValidationError < RuntimeError; end

  delegate :fetch_metrics_available, :to => :metrics_capture
  delegate :collect_live_metrics, :to => :metrics_capture
  delegate :collect_stats_metrics, :to => :metrics_capture

  included do
    def live_metrics_name
      self.class.name.demodulize.underscore
    end

    def chart_report_name
      self.class.name.demodulize.underscore
    end

    def metrics_available
      @metrics_available ||= fetch_metrics_available
    end

    def first_and_last_capture(interval_name = "realtime")
      firsts, lasts = metrics_capture.first_and_last_capture_for_metrics(metrics_available)
      adjust_timestamps(firsts, lasts, interval_name)
    rescue => e
      _log.error("LiveMetrics unavailable for #{self.class.name} id: #{id}. #{e.message}")
      return [nil, nil]
    end

    def adjust_timestamps(firsts, lasts, interval_name)
      first = Time.at(firsts.min / 1000).utc
      last = Time.at(lasts.max / 1000).utc
      now = Time.new.utc
      first = nil if interval_name == "hourly" && (now - first) <= 1.hour
      [first, last]
    end

    def included_children
      self.class.live_metrics_config[live_metrics_name]['included_children']
    end

    def supported_metrics
      self.class.live_metrics_config[live_metrics_name]['supported_metrics']
    end

    def supported_metrics_by_column
      self.class.live_metrics_config[live_metrics_name]['supported_metrics_by_column']
    end
  end

  module ClassMethods
    def supported_models
      @supported_models ||= [name.demodulize.underscore]
    end

    def live_metrics_config
      @live_metrics_config ||= {}
      supported_models.each do |model_name|
        @live_metrics_config[model_name] ||= load_live_metrics_config(model_name)
        @live_metrics_config[model_name]['supported_metrics_by_column'] =
          @live_metrics_config[model_name]['supported_metrics'].invert
      end
      @live_metrics_config
    end

    def load_live_metrics_config(config_file)
      live_metrics_file = File.join(LIVE_METRICS_DIR, "#{config_file}.yaml")
      live_metrics_config = File.exist?(live_metrics_file) ? YAML.load_file(live_metrics_file) : {}
      if live_metrics_config['supported_metrics']
        live_metrics_config['supported_metrics'] = live_metrics_config['supported_metrics'].reduce({}, :merge)
      end
      live_metrics_config
    end
  end
end
