module ManageIQ::Providers
  class Hawkular::MiddlewareManager::LiveMetricsCapture
    class MetricValidationError < RuntimeError; end

    MetricsResource = Struct.new(:id, :feed, :path)

    def initialize(target)
      @target = target
      @ems = @target.ext_management_system
      @gauges = @ems.metrics_client.gauges
      @counters = @ems.metrics_client.counters
      @avail = @ems.metrics_client.avail
    end

    def fetch_metrics_available
      resource = MetricsResource.new
      resource.id = @target.nativeid
      resource.feed = extract_feed(@target.ems_ref)
      resource.path = @target.ems_ref
      @ems.metrics_resource(resource.path).collect do |metric|
        next unless @target.class.supported_metrics[metric.name]
        {
          :id   => metric.id,
          :name => @target.class.supported_metrics[metric.name],
          :type => metric.type,
          :unit => metric.unit
        }
      end.compact
    end

    def collect_live_metric(metric, start_time, end_time, interval)
      validate_metric(metric)
      starts = (start_time - interval).to_i.in_milliseconds
      ends = end_time.to_i.in_milliseconds + 1
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
      sort_and_normalize(@counters.get_rate(metric_id, :starts => starts, :ends => ends,
                                          :bucket_duration => bucket_duration))
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

    def process_data(metric, data)
      data.each_with_object({}) do |x, processed|
        timestamp = Time.at(x['start'] / 1.in_milliseconds).utc.to_i
        value = metric[:type] == 'AVAILABILITY' ? x['uptimeRatio'] : x['avg']
        processed.store_path(timestamp, metric[:name], value)
      end
    end

    private

    def extract_feed(ems_ref)
      s_start = ems_ref.index("/f;") + 3
      s_end = ems_ref.index("/", s_start) - 1
      ems_ref[s_start..s_end]
    end
  end
end
