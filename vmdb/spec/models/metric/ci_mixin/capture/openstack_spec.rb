require "spec_helper"

describe Metric::CiMixin::Capture::Openstack do
  require File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. .. tools openstack_data openstack_data_test_helper}))

  before :each do
    MiqRegion.seed
    guid, server, @zone = EvmSpecHelper.create_guid_miq_server_zone

    @mock_meter_list = OpenstackMeterListData.new
    @mock_stats_data = OpenstackMetricStatsData.new

    @ems_openstack = FactoryGirl.create(:ems_openstack, :zone => @zone)
    @ems_openstack.stub(:list_meters).and_return(
      OpenstackApiResult.new(@mock_meter_list.list_meters("resource_counters")),
      OpenstackApiResult.new(@mock_meter_list.list_meters("metadata_counters")))

    @vm = FactoryGirl.create(:vm_perf_openstack, :ext_management_system => @ems_openstack)
    @vm.stub(:perf_init_openstack).and_return(@ems_openstack)
  end

  context "with standard interval data" do
    before :each do
      @ems_openstack.stub(:get_statistics) { |name, options| OpenstackApiResult.new(@mock_stats_data.get_statistics(name)) }
    end

    it "treats openstack timestamp as UTC" do
      ts_as_utc = api_time_as_utc(@mock_stats_data.get_statistics("cpu_util").last)
      counters, values_by_id_and_ts = @vm.perf_collect_metrics_openstack("realtime")
      ts = Time.parse(values_by_id_and_ts[@vm.ems_ref].keys.sort.last)

      ts_as_utc.should eq ts
    end

    it "translates cumulative meters into discrete values" do
      counter_info = Metric::Capture::Openstack::COUNTER_INFO.find {|c| c[:vim_style_counter_key] == "disk_usage_rate_average" }

      # the next 4 steps are test comparison data setup

      # 1. grab the 3rd-to-last, 2nd-to-last and last API results for disk read/writes
      # need 3rd-to-last to get the interval for the 2nd-to-last values
      *_, read_bytes_prev, read_bytes1, read_bytes2 = @mock_stats_data.get_statistics("disk.read.bytes")
      *_, write_bytes_prev, write_bytes1, write_bytes2 = @mock_stats_data.get_statistics("disk.write.bytes")

      read_ts_prev = api_time_as_utc(read_bytes_prev)
      write_ts_prev = api_time_as_utc(write_bytes_prev)

      # 2. calculate the disk_usage_rate_average for the 2nd-to-last API result
      read_ts1 = api_time_as_utc(read_bytes1)
      read_val1 = read_bytes1["avg"]
      write_ts1 = api_time_as_utc(write_bytes1)
      write_val1 = write_bytes1["avg"]
      disk_val1 = counter_info[:calculation].call(read_val1, write_val1, read_ts1 - read_ts_prev)

      # 3. calculate the disk_usage_rate_average for the last API result
      read_ts2 = api_time_as_utc(read_bytes2)
      read_val2 = read_bytes2["avg"]
      write_ts2 = api_time_as_utc(write_bytes2)
      write_val2 = write_bytes2["avg"]
      disk_val2 = counter_info[:calculation].call(read_val2, write_val2, read_ts2 - read_ts1)

      # 4. disk_val1 and disk_val2 are cumulative values
      # calculate the diff to provide a discrete value for the duration
      disk_val = disk_val2 - disk_val1

      # get the actual values from the method
      _, values_by_id_and_ts = @vm.perf_collect_metrics_openstack("realtime")
      values_by_ts = values_by_id_and_ts[@vm.ems_ref]

      # make sure that the last calculated value is the same as the discrete value
      # calculated in step #4 above
      *_, result = values_by_ts

      result[read_ts2.iso8601]["disk_usage_rate_average"].should eq disk_val
    end
  end

  context "with irregular interval data" do
    before do
      @ems_openstack.stub(:get_statistics) do |name, _options|
        OpenstackApiResult.new(@mock_stats_data.get_statistics(name, "irregular_interval"))
      end

      @orig_log = $log
      $log = double.as_null_object
    end

    after do
      $log = @orig_log
    end

    it "normalizes irregular intervals into 20sec intervals" do
      _, values_by_id_and_ts = @vm.perf_collect_metrics_openstack("realtime")
      values_by_ts = values_by_id_and_ts[@vm.ems_ref]
      ts_keys = values_by_ts.keys

      # the first two openstack metrics should look like:
      #   ts: 2013-08-28T11:01:09 => cpu_util: 50
      #   ts: 2013-08-28T11:02:12 => cpu_util: 100
      #
      # after capture and processing, the first six statistics should look like:
      #   ts: 2013-08-28T11:01:09 => cpu_usage_rate_average: 50
      #   ts: 2013-08-28T11:01:29 => cpu_usage_rate_average: 50
      #   ts: 2013-08-28T11:01:49 => cpu_usage_rate_average: 50
      #   ts: 2013-08-28T11:02:09 => cpu_usage_rate_average: 75
      #   ts: 2013-08-28T11:02:29 => cpu_usage_rate_average: 100
      #   ts: 2013-08-28T11:02:49 => cpu_usage_rate_average: 100
      #
      # where:
      #   * the first 3 stats are an equal 20 second break down of the first
      #     openstack metric
      #   * the 4th stat is an average of the two captured openstack metrics
      #     because the stored timestamp (keeping with the 20 second periods) is
      #     between the two captured openstack metrics
      #   * and the next 2 stats are an equal 20 second break down of the second
      #     openstack metric

      # these values are pulled directly from spec/tools/openstack_data/openstack_perf_data/irregular_interval.yml
      avg_stat1 = 50
      avg_stat2 = 100

      # ensure that the first three statistics match avg_stat1
      (0..2).each { |i| values_by_ts[ts_keys[i]]["cpu_usage_rate_average"].should eq avg_stat1 }

      # ensure the fourth statistic is the avg of stat1 and stat2
      stat = (avg_stat1 + avg_stat2) / 2
      values_by_ts[ts_keys[3]]["cpu_usage_rate_average"].should eq stat

      # the fifth and sixth stat should match avg_stat2
      (4..5).each { |i| values_by_ts[ts_keys[i]]["cpu_usage_rate_average"].should eq avg_stat2 }
    end

    it "logs when capture intervals are too small" do
      $log.should_receive(:warn).with(/Capture interval invalid/).at_least(:once)
      @vm.perf_collect_metrics_openstack("realtime")
    end
  end

  def api_time_as_utc(api_result)
    Time.parse("#{api_result["duration_end"]}Z")
  end
end
