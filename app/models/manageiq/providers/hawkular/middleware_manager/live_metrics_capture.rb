module ManageIQ::Providers
  class Hawkular::MiddlewareManager::LiveMetricsCapture
    class MetricValidationError < RuntimeError; end

    def initialize(target)
      @target = target
      @ems = @target.ext_management_system
      @metrics_client = @ems.metrics_client
      @gauges = @metrics_client.gauges
      @counters = @metrics_client.counters
      @avail = @metrics_client.avail
      @included_children = @target.included_children
      @supported_metrics = @target.supported_metrics
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

    def parse_metrics_ids(metrics)
      gauge_ids = []
      counter_ids = []
      avail_ids = []
      metrics_ids_map = {}
      metrics.each do |metric|
        metric_id = metric[:id]
        case metric[:type]
        when "GAUGE"        then gauge_ids.push(metric_id)
        when "COUNTER"      then counter_ids.push(metric_id)
        when "AVAILABILITY" then avail_ids.push(metric_id)
        end
        metrics_ids_map[metric_id] = metric[:name]
      end
      [gauge_ids, counter_ids, avail_ids, metrics_ids_map]
    end

    def collect_stats_metrics(metrics, start_time, end_time, interval)
      gauge_ids, counter_ids, avail_ids, metrics_ids_map = parse_metrics_ids(metrics)
      starts = start_time.to_i.in_milliseconds
      ends = (end_time + interval).to_i.in_milliseconds + 1
      bucket_duration = "#{interval}s"
      raw_stats = @metrics_client.query_stats(:gauge_ids       => gauge_ids,
                                              :counter_ids     => counter_ids,
                                              :avail_ids       => avail_ids,
                                              :rates           => true,
                                              :starts          => starts,
                                              :ends            => ends,
                                              :bucket_duration => bucket_duration)
      [metrics_ids_map, raw_stats]
    end

    def collect_live_metrics(metrics, start_time, end_time, interval)
      metrics_ids_map, raw_stats = collect_stats_metrics(metrics, start_time, end_time, interval)
      process_stats(metrics_ids_map, raw_stats)
    end

    def process_stats(metrics_ids_map, raw_stats)
      processed = Hash.new { |h, k| h[k] = {} }
      %w(availability gauge counter_rate).each do |type|
        next unless raw_stats.key?(type)
        raw_data = raw_stats[type]
        raw_data.each do |metric_id, buckets|
          metric_name = metrics_ids_map[metric_id]
          norm_data = sort_and_normalize(buckets)
          norm_data.each do |bucket|
            timestamp = Time.at(bucket['start'] / 1.in_milliseconds).utc.to_i
            value = type == 'availability' ? bucket['uptimeRatio'] : bucket['avg']
            processed.store_path(timestamp, metric_name, value)
          end
        end
      end
      processed
    end

    def first_and_last_capture_for_metrics(metrics)
      firsts, lasts = metrics.collect do |metric|
        first_and_last_capture(metric)
      end.transpose
      [firsts, lasts]
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
      metric_def = client.get(metric_id)
      [metric_def.json['minTimestamp'], metric_def.json['maxTimestamp']]
    end

    def sort_and_normalize(data)
      # Sorting and removing last entry because always incomplete
      # as it's still in progress.
      norm_data = (data.sort_by { |x| x['start'] }).slice(0..-2)
      norm_data.reject { |x| x.values.include?('NaN') }
    end

    private

    def extract_feed(ems_ref)
      s_start = ems_ref.index("/f;") + 3
      s_end = ems_ref.index("/", s_start) - 1
      ems_ref[s_start..s_end]
    end
  end
end
