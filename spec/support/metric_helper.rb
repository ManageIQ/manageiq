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
          MiqQueue.where(:method_name => %w[perf_capture_hourly perf_capture_realtime perf_capture_historical])
        )

        expect(selected).to match_array(expected)
      end

      # @return [Array<Array<Object, String>>] List of object and interval names in miq queue
      def queue_intervals(items)
        items.map do |q|
          interval_name = q.method_name.sub("perf_capture_", "")
          [Object.const_get(q.class_name).find(q.instance_id), interval_name]
        end
      end

      def stub_performance_settings(hash)
        stub_settings(:performance => hash)
      end
    end
  end
end

# These contexts expect the following setup:
#
# before do
#   MiqRegion.seed
#   @zone = EvmSpecHelper.local_miq_server.zone
# end
RSpec.shared_context 'with enabled/disabled vmware targets', :with_enabled_disabled_vmware do
  before do
    @ems_vmware = FactoryBot.create(:ems_vmware, :zone => @zone)
    @storages = FactoryBot.create_list(:storage_target_vmware, 2)
    @vmware_clusters = FactoryBot.create_list(:cluster_target, 2)
    @ems_vmware.ems_clusters = @vmware_clusters

    6.times do |n|
      host = FactoryBot.create(:host_target_vmware, :ext_management_system => @ems_vmware)
      @ems_vmware.hosts << host

      @vmware_clusters[n / 2].hosts << host if n < 4
      host.storages << @storages[n / 3]
    end

    MiqQueue.delete_all
    @ems_vmware.reload
  end

  let(:all_targets) { Metric::Targets.capture_ems_targets(@ems_vmware) }
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

RSpec.shared_context "with openstack", :with_openstack_and_availability_zones do
  before do
    @ems_openstack = FactoryBot.create(:ems_openstack, :zone => @zone)
    @availability_zone = FactoryBot.create(:availability_zone_target)
    @ems_openstack.availability_zones << @availability_zone
    @vms_in_az = FactoryBot.create_list(:vm_openstack, 2, :ems_id => @ems_openstack.id)
    @availability_zone.vms = @vms_in_az
    @availability_zone.vms.push(FactoryBot.create(:vm_openstack, :ems_id => nil))
    @vms_not_in_az = FactoryBot.create_list(:vm_openstack, 3, :ems_id => @ems_openstack.id)

    MiqQueue.delete_all
  end
end
