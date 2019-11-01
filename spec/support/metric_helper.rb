module Spec
  module Support
    module MetricHelper
      # given (enabled) capture_targets, compare with suggested queue entries
      def assert_metric_targets(expected_targets)
        expected = expected_targets.flat_map do |t|
          # Storage is hourly only
          # Non-storage historical is expecting 7 days back, plus partial day = 8
          t.kind_of?(Storage) ? [[t, "hourly"]] : [[t, "realtime"]] + [[t, "historical"]] * 8
        end
        selected = queue_intervals(
          MiqQueue.where(:method_name => %w(perf_capture_hourly perf_capture_realtime perf_capture_historical)))

        expect(selected).to match_array(expected)
      end

      # @return [Array<Array<Object, String>>] List of object and interval names in miq queue
      def queue_intervals(items)
        items.map do |q|
          interval_name = q.method_name.sub("perf_capture_", "")
          [Object.const_get(q.class_name).find(q.instance_id), interval_name]
        end
      end
    end
  end
end
