module ManageIQ::Providers
  class Kubernetes::ContainerManager::MetricsCapture < BaseManager::MetricsCapture
    class CollectionFailure < RuntimeError; end
    class TargetValidationError < RuntimeError; end

    require_nested :CaptureContext

    INTERVAL = 20.seconds

    VIM_STYLE_COUNTERS = {
      "cpu_usage_rate_average"     => {
        :counter_key           => "cpu_usage_rate_average",
        :instance              => "",
        :capture_interval      => "#{INTERVAL}",
        :precision             => 1,
        :rollup                => "average",
        :unit_key              => "percent",
        :capture_interval_name => "realtime"
      },
      "mem_usage_absolute_average" => {
        :counter_key           => "mem_usage_absolute_average",
        :instance              => "",
        :capture_interval      => "#{INTERVAL}",
        :precision             => 1,
        :rollup                => "average",
        :unit_key              => "percent",
        :capture_interval_name => "realtime"
      },
      "net_usage_rate_average" => {
        :counter_key           => "net_usage_rate_average",
        :instance              => "",
        :capture_interval      => "#{INTERVAL}",
        :precision             => 2,
        :rollup                => "average",
        :unit_key              => "datagramspersecond",
        :capture_interval_name => "realtime"
      }
    }

    def perf_collect_metrics(interval_name, start_time = nil, end_time = nil)
      start_time ||= 15.minutes.ago.beginning_of_minute.utc

      target_name = "#{target.class.name.demodulize}(#{target.id})"
      _log.info("Collecting metrics for #{target_name} [#{interval_name}] " \
                "[#{start_time}] [#{end_time}]")

      begin
        context = CaptureContext.new(target, start_time, end_time, INTERVAL)
      rescue TargetValidationError => e
        _log.error("#{target_name} is not valid: #{e.message}")
        return [{}, {}]
      end

      Benchmark.realtime_block(:collect_data) do
        begin
          context.collect_metrics
        rescue CollectionFailure => e
          _log.error("Hawkular metrics service unavailable: #{e.message}")
          return [{}, {}]
        end
      end

      [{target.ems_ref => VIM_STYLE_COUNTERS},
       {target.ems_ref => context.ts_values}]
    end
  end
end
