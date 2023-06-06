module Spec
  module Support
    module MetricHelper
      # method_name => {target => [timing1, timing2] }
      # for each capture type, what objects are submitted and what are their time frames
      #
      # The objects can be added as a batch or invididually. Additionally dates can be
      # split up into multiple date ranges.
      # This method undoes the batching and splitting to make testing more consistent
      #
      # @return [Hash{String => Hash{Object => Array<Array>}} ]
      #         {"Vm:1" => [[start_time1, finish_time1], [start_time2, finish_time2]]}
      def queue_timings(items = MiqQueue.where(:method_name => %w[perf_capture_hourly perf_capture_realtime perf_capture_historical]))
        messages = {}
        items.each do |q|
          klass = q.class_name.constantize.base_class.name
          # If the third argument contains a list of object ids
          # we denormalize to one message per object_id
          date_first, date_end, ids, *_ = q.args
          ids = [q.instance_id] if ids.blank?
          objs = ids.sort.map { |id| "#{klass}:#{id}" }

          objs.each do |obj|
            interval_name = q.method_name.sub("perf_capture_", "")

            # historical captures have a date range, while realtime captures do not.
            messages[interval_name] ||= {}
            (messages[interval_name][obj] ||= []) << (date_first ? [date_first, date_end] : [])
          end
        end
        # there can be multiple messages for a large date range
        # this will combine multiple consecutive date ranges into larger ones
        messages["historical"]&.transform_values! { |v| combine_consecutive(v) }

        messages
      end

      # to make test failures easier to read, use parent_class:id
      def queue_object(object)
        "#{object.class.base_class.name}:#{object.id}"
      end

      def arg_day_range(start_time, end_time)
        [[start_time, end_time]]
      end

      def stub_performance_settings(hash)
        stub_settings(:performance => hash)
      end

      # @param batch_size [Numeric] defaults to nil / no batching
      def ems_concurrent_requests(ems, batch_size = nil)
        {
          "ems_#{ems}".to_sym => {
            :concurrent_requests => {
              :historical => batch_size,
              :hourly     => batch_size,
              :realtime   => batch_size
            }
          }
        }
      end

      private

      def combine_consecutive(array)
        prev_first, prev_end = array.sort!.shift
        array.each_with_object([]) do |(cur_first, cur_end), ac|
          # It can overlap or abut, we want to join both of those
          #   prev=1-1-2000T0..23:59, cur=1-2-2000T0..23:59
          #   prev=1-1-2000T0..24:00, cur=1-2-2000T0..24:00
          if cur_first <= (prev_end + 1.second)
            prev_end = cur_end
          else
            ac << [prev_first, prev_end]
            prev_first, prev_end = cur_first, cur_end
          end
        end << [prev_first, prev_end]
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
