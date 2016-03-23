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
      @gauges = @ems.metrics_connect.gauges
      @counters = @ems.metrics_connect.counters
      @avail = @ems.metrics_connect.avail
    end

    def metrics_available
      resource = Struct.new(:id, :feed).new
      resource.id = @target.nativeid
      resource.feed = @target.feed
      @ems.metrics_resource(resource).collect do |metric|
        {
          :id   => metric.id,
          :name => @target.class::METRICS_HWK_MIQ[metric.name],
          :type => metric.type,
          :unit => metric.unit
        }
      end
    end

    def collect_live_metric(metric, start_time, end_time, interval)
      validate_metric(metric)
      starts = (start_time - interval).to_i.in_milliseconds
      ends = end_time.to_i.in_milliseconds
      bucket_duration = "#{interval}s"
      metrics = fetch_metrics(metric[:id], metric[:type], starts, ends, bucket_duration)
      process_data(metric, metrics)
    end

    def first_and_last_capture(metric)
      validate_metric(metric)
      case metric[:type]
      when "GAUGE"        then min_max_timestamps(@gauges, metric[:id])
      when "COUNTER"      then min_max_timestamps(@counters, metric[:id])
      when "AVAILABILITY" then min_max_timestamps(@avail, metric[:id])
      else raise MetricValidationError, "Validation error: unknown type #{metric_type}"
      end
    end

    def validate_metric(metric)
      unless metric && %i(id name type unit).all? { |k| metric.key?(k) }
        raise MetricValidationError, "Validation error: metric #{metric} must be defined"
      end
    end

    def min_max_timestamps(client, metric_id)
      min = client.get_data(metric_id, :starts => 0, :limit => 1, :order => 'ASC')
      max = client.get_data(metric_id, :starts => 0, :limit => 1, :order => 'DESC')
      [min[0]['timestamp'], max[0]['timestamp']]
    end

    def fetch_metrics(metric_id, metric_type, starts, ends, bucket_duration)
      case metric_type
      when "GAUGE"        then gauges(metric_id, starts, ends, bucket_duration)
      when "COUNTER"      then counters(metric_id, starts, ends, bucket_duration)
      when "AVAILABILITY" then availabilities(metric_id, starts, ends, bucket_duration)
      else raise MetricValidationError, "Validation error: unknown type #{metric_type}"
      end
    end

    def gauges(metric_id, starts, ends, bucket_duration)
      sort_and_normalize(@gauges.get_data(metric_id, :starts => starts, :ends => ends,
                                          :bucketDuration => bucket_duration))
    end

    def counters(metric_id, starts, ends, bucket_duration)
      compute_derivates(sort_and_normalize(@counters.get_data(metric_id, :starts => starts, :ends => ends,
                                                              :bucketDuration => bucket_duration)))
    end

    def availabilities(metric_id, starts, ends, bucket_duration)
      sort_and_normalize(@avail.get_data(metric_id, :starts => starts, :ends => ends,
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
      data.each_with_object({}) do |x, processed|
        timestamp = Time.at(x['start'] / 1.in_milliseconds).utc.to_i
        value = metric[:type] == 'AVAILABILITY' ? x['uptimeRatio'] : x['avg']
        processed.store_path(timestamp, metric[:name], value)
      end
    end
  end
end
