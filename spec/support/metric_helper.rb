module Spec
  module Support
    module MetricHelper
      # given (enabled) capture_targets, compare with suggested queue entries
      def metric_targets(expected_targets)
        expected_targets.flat_map do |t|
          # Storage is hourly only
          # Non-storage historical is expecting 7 days back, plus partial day = 8
          t.kind_of?(Storage) ? [[t, "hourly"]] : [[t, "realtime"]] + [[t, "historical"]] * 8
        end
      end

      # @return [Array<Array<Object, String>>] List of object and interval names in miq queue
      def queue_intervals(items = MiqQueue.where(:method_name => %w[perf_capture_hourly perf_capture_realtime perf_capture_historical]))
        items.map do |q|
          interval_name = q.method_name.sub("perf_capture_", "")
          [Object.const_get(q.class_name).find(q.instance_id), interval_name]
        end
      end

      # method_name => {target => [timing1, timing2] }
      # for each capture type, what objects are submitted and what are their time frames
      # @return [Hash{String => Hash{Object => Array<Array>}} ]
      def queue_timings(items = MiqQueue.where(:method_name => %w[perf_capture_hourly perf_capture_realtime perf_capture_historical]))
        messages = {}
        items.each do |q|
          obj = q.instance_id ? Object.const_get(q.class_name).find(q.instance_id) : q.class_name.constantize

          interval_name = q.method_name.sub("perf_capture_", "")

          messages[interval_name] ||= {}
          (messages[interval_name][obj] ||= []) << q.args
        end
        messages["historical"]&.transform_values!(&:sort!)

        messages
      end

      # sorry, stole from the code - not really testing
      def arg_day_range(start_time, end_time, threshold = 1.day)
        (start_time.utc..end_time.utc).step_value(threshold).each_cons(2).collect do |s_time, e_time|
          [s_time, e_time]
        end
      end

      def stub_performance_settings(hash)
        stub_settings(:performance => hash)
      end
    end
  end
end

RSpec.shared_context "with a small environment and time_profile", :with_small_vmware do
  before do
    @ems_vmware = FactoryBot.create(:ems_vmware, :zone => @zone)
    @vm1 = FactoryBot.create(:vm_vmware)
    @vm2 = FactoryBot.create(:vm_vmware, :hardware => FactoryBot.create(:hardware, :cpu1x2, :memory_mb => 4096))
    @host1 = FactoryBot.create(:host, :hardware => FactoryBot.create(:hardware, :memory_mb => 8124, :cpu_total_cores => 1, :cpu_speed => 9576), :vms => [@vm1])
    @host2 = FactoryBot.create(:host, :hardware => FactoryBot.create(:hardware, :memory_mb => 8124, :cpu_total_cores => 1, :cpu_speed => 9576))

    @ems_cluster = FactoryBot.create(:ems_cluster, :ext_management_system => @ems_vmware)
    @ems_cluster.hosts << @host1
    @ems_cluster.hosts << @host2

    @time_profile = FactoryBot.create(:time_profile_utc)

    MiqQueue.delete_all
  end
end
