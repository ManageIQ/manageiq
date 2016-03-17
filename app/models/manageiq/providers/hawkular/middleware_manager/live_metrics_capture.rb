module ManageIQ::Providers
  class Hawkular::MiddlewareManager::LiveMetricsCapture
    class TargetValidationError < RuntimeError; end
    class MetricValidationError < RuntimeError; end

    def initialize(target)
      @target = target
      unless @target.kind_of?(MiddlewareServer)
        raise TargetValidationError, "Validation error: unknown target"
      end
      @ems = @target.ext_management_system
    end

    def metrics_available
      resource = Struct.new(:id, :feed).new
      resource.id = @target.nativeid
      resource.feed = @target.feed
      available = []
      @ems.metrics_resource(resource).each do |metric|
        available << {
          :id   => metric.id,
          :name => @target.class::METRICS_HWK_MIQ[metric.name],
          :type => metric.type,
          :unit => metric.unit
        }
      end
      available
    end

    def validate_metric(metric)
      if metric.nil?
        false
      elsif metric[:id].nil?
        false
      elsif metric[:name].nil?
        false
      elsif metric[:type].nil?
        false
      elsif metric[:unit].nil?
        false
      else
        true
      end
    end

    def metric(metric, start_time, end_time, interval)
      unless validate_metric(metric)
        raise MetricValidationError, "Validation error: metric must be defined"
      end
      starts = (start_time - interval).to_i.in_milliseconds
      ends = end_time.to_i.in_milliseconds
      bucket_duration = "#{interval}s"
      metrics = collect_metrics(metric[:id], metric[:type], starts, ends, bucket_duration)
      process_data(metric, metrics)
    end

    def collect_metrics(metric_id, metric_type, starts, ends, bucket_duration)
      case metric_type
      when "GAUGE" then gauges(metric_id, starts, ends, bucket_duration)
      when "COUNTER" then counters(metric_id, starts, ends, bucket_duration)
      when "AVAILABILITY" then availabilities(metric_id, starts, ends, bucket_duration)
      else raise MetricValidationError, "Validation error: unknown type #{metric_type}"
      end
    end

    def gauges(metric_id, starts, ends, bucket_duration)
      sort_and_normalize(
        @ems.metrics_connect.gauges.get_data(metric_id, :starts => starts, :ends => ends,
                                             :bucketDuration => bucket_duration))
    end

    def counters(metric_id, starts, ends, bucket_duration)
      compute_derivates(
        sort_and_normalize(
          @ems.metrics_connect.counters.get_data(metric_id, :starts => starts, :ends => ends,
                                                 :bucketDuration => bucket_duration)))
    end

    def availabilities(metric_id, starts, ends, bucket_duration)
      sort_and_normalize(
        @ems.metrics_connect.avail.get_data(metric_id, :starts => starts, :ends => ends,
                                            :bucketDuration => bucket_duration))
    end

    def sort_and_normalize(data)
      # Sorting and removing last entry because always incomplete
      # as it's still in progress.
      norm_data = (data.sort_by { |x| x['start'] }).slice(0..-2)
      norm_data.reject { |x| x.values.include?('NaN') }
    end

    def compute_derivates(counters)
      counters.each_cons(2).map do |prv, n|
        # Add min, median, max, percentile95th, etc. if needed
        {
          'start' => n['start'],
          'end'   => n['end'],
          'avg'   => n['avg'] - prv['avg']
        }
      end
    end

    def process_data(metric, data)
      processed = Hash.new { |h, k| h[k] = {} }
      data.each do |x|
        timestamp = Time.at(x['start'] / 1.in_milliseconds).utc.to_i
        processed[timestamp][metric[:name]] = if metric[:type] == 'AVAILABILITY'
                                                x['uptimeRatio']
                                              else
                                                x['avg']
                                              end
      end
      processed
    end
  end
end
