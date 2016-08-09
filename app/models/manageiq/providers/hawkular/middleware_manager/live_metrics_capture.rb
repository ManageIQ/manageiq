module ManageIQ::Providers
  class Hawkular::MiddlewareManager::LiveMetricsCapture
    class MetricValidationError < RuntimeError; end

    def initialize(target)
      @target = target
      @ems = @target.ext_management_system
      @gauges = @ems.metrics_client.gauges
      @counters = @ems.metrics_client.counters
      @avail = @ems.metrics_client.avail
      @included_children = @target.class.included_children
      @supported_metrics = @target.class.supported_metrics
    end

    def fetch_metrics_available
      metrics_available = @ems.metrics_resource(@target.ems_ref).collect do |metric|
        next unless @supported_metrics[metric.type_id]
        parse_metric(metric)
      end.compact
      fetch_child_metrics(@target.ems_ref, metrics_available) if @included_children
      metrics_available
    end

    def fetch_child_metrics(resource_path, metrics_available)
      children = @ems.child_resources(resource_path)
      children.select { |child| @included_children.include?(child.name) }.each do |child|
        @ems.metrics_resource(child.path).select { |metric| @supported_metrics[metric.type_id] }.each do |metric|
          metrics_available << parse_metric(metric)
        end
      end
      metrics_available
    end

    def parse_metric(metric)
      {:id => metric.id, :name => @supported_metrics[metric.type_id], :type => metric.type, :unit => metric.unit}
    end

    def collect_live_metric(metric, start_time, end_time, interval)
      validate_metric(metric)
      starts = (start_time - interval).to_i.in_milliseconds
      ends = end_time.to_i.in_milliseconds + 1
      bucket_duration = "#{interval}s"
      metrics = fetch_metrics(metric[:id], metric[:type], starts, ends, bucket_duration)
      process_data(metric, metrics)
    end

    def collect_stats_metric(metric, start_time, end_time, interval)
      validate_metric(metric)
      starts = start_time.to_i.in_milliseconds
      ends = end_time.to_i.in_milliseconds
      bucket_duration = "#{interval}s"
      fetch_raw_metrics(metric[:id], metric[:type], starts, ends, bucket_duration)
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
      sort_and_normalize(fetch_raw_metrics(metric_id, metric_type, starts, ends, bucket_duration))
    end

    def fetch_raw_metrics(metric_id, metric_type, starts, ends, bucket_duration)
      data = case metric_type
             when "GAUGE"
               @gauges.get_data(metric_id, :starts => starts, :ends => ends, :bucketDuration => bucket_duration)
             when "COUNTER"
               @counters.get_rate(metric_id, :starts => starts, :ends => ends, :bucket_duration => bucket_duration)
             when "AVAILABILITY"
               @avail.get_data(metric_id, :starts => starts, :ends => ends, :bucketDuration => bucket_duration)
             else
               raise MetricValidationError, "Validation error: unknown type #{metric_type}"
             end
      data
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
