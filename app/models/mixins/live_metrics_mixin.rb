module LiveMetricsMixin
  extend ActiveSupport::Concern

  LIVE_METRICS_DIR = Rails.root.join("product/live_metrics")

  class MetricValidationError < RuntimeError; end

  delegate :first_and_last_capture, :to => :metrics_capture
  delegate :fetch_metrics_available, :to => :metrics_capture
  delegate :collect_live_metrics, :to => :metrics_capture
  delegate :collect_report_metrics, :to => :metrics_capture

  included do
    def live_metrics_type
      'default'
    end

    def chart_report_name
      self.class.name.demodulize.underscore
    end

    def metrics_available
      @metrics_available ||= fetch_metrics_available
    end

    def included_children
      self.class.live_metrics_config['included_children']
    end

    def supported_metrics
      self.class.live_metrics_config['supported_metrics']
    end

    def supported_metrics_by_column
      self.class.live_metrics_config['supported_metrics_by_column']
    end
  end

  module ClassMethods
    def live_metrics_config
      @live_metrics_config ||= load_live_metrics_config
    end

    def load_live_metrics_config
      live_metrics_file = File.join(LIVE_METRICS_DIR, "#{name.demodulize.underscore}.yaml")
      live_metrics_config = File.exist?(live_metrics_file) ? YAML.load_file(live_metrics_file) : {}
      if live_metrics_config['supported_metrics']
        live_metrics_config['supported_metrics_by_column'] = {}
        live_metrics_config['supported_metrics'].each do |key, value|
          if value
            live_metrics_config['supported_metrics'][key] = value.reduce({}, :merge)
            live_metrics_config['supported_metrics_by_column'][key] = live_metrics_config['supported_metrics'][key].invert
          end
        end
      end
      live_metrics_config
    end
  end
end
