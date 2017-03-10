describe Metric::CiMixin::Capture do
  require File.expand_path(File.join(File.dirname(__FILE__),
                                     %w(.. .. .. tools openstack_data openstack_data_test_helper)))

  before :each do
    _guid, _server, @zone = EvmSpecHelper.create_guid_miq_server_zone

    @mock_meter_list = OpenstackMeterListData.new
    @mock_stats_data = OpenstackMetricStatsData.new

    @metering = double(:metering)
    allow(@metering).to receive(:list_meters).and_return(
      OpenstackApiResult.new((@mock_meter_list.list_meters("resource_counters") +
                              @mock_meter_list.list_meters("metadata_counters"))))

    @ems_openstack = FactoryGirl.create(:ems_openstack, :zone => @zone)
    allow(@ems_openstack).to receive(:connect).with(:service => "Metering").and_return(@metering)

    @vm = FactoryGirl.create(:vm_perf_openstack, :ext_management_system => @ems_openstack)
  end

  before do
    @orig_log = $log
    $log = double.as_null_object
  end

  after do
    $log = @orig_log
  end

  def expected_stats_period_start
    parse_datetime('2013-08-28T11:01:20Z')
  end

  def expected_stats_period_end
    parse_datetime('2013-08-28T12:41:40Z')
  end

  context "2 collection periods total, end of 1. period has incomplete stat" do
    ###################################################################################################################
    # DESCRIPTION FOR: net_usage_rate_average
    # MAIN SCENARIOS :

    it "checks that saved metrics are correct" do
      capture_data('2013-08-28T12:02:00Z', 20.minutes)

      stats_period_start = [api_time_as_utc(@read_bytes.first), api_time_as_utc(@write_bytes.first)].min
      stats_period_end = [api_time_as_utc(@read_bytes.last), api_time_as_utc(@write_bytes.last)].min

      # check start date and end date
      expect(stats_period_start).to eq expected_stats_period_start
      expect(stats_period_end).to eq expected_stats_period_end

      # check that 20s block is not interrupted between start and end time for net_usage_rate_average
      stats_counter = 0
      (expected_stats_period_start + 20.seconds..expected_stats_period_end).step_value(20.seconds).each do |timestamp|
        expect(@metrics_by_ts[timestamp.iso8601].try(:net_usage_rate_average)).not_to eq nil
        stats_counter += 1
      end

      # check that 20s block is not interrupted between start and end time for disk_usage_rate_average
      stats_counter = 0
      (expected_stats_period_start + 20.seconds..expected_stats_period_end).step_value(20.seconds).each do |timestamp|
        expect(@metrics_by_ts[timestamp.iso8601].try(:disk_usage_rate_average)).not_to eq nil
        stats_counter += 1
      end

      # check that 20s block is not interrupted between start and end time for cpu_usage_rate_average
      stats_counter = 0
      (expected_stats_period_start + 20.seconds..expected_stats_period_end).step_value(20.seconds).each do |timestamp|
        expect(@metrics_by_ts[timestamp.iso8601].try(:cpu_usage_rate_average)).not_to eq nil
        stats_counter += 1
      end
    end
  end

  context "2 collection periods total, end of 1. period has complete stats" do
    ###################################################################################################################
    # DESCRIPTION FOR: net_usage_rate_average
    # MAIN SCENARIOS :

    it "checks that saved metrics are correct" do
      capture_data('2013-08-28T12:06:00Z', 20.minutes)

      stats_period_start = [api_time_as_utc(@read_bytes.first), api_time_as_utc(@write_bytes.first)].min
      stats_period_end = [api_time_as_utc(@read_bytes.last), api_time_as_utc(@write_bytes.last)].min

      # check start date and end date
      expect(stats_period_start).to eq expected_stats_period_start
      expect(stats_period_end).to eq expected_stats_period_end

      # check that 20s block is not interrupted between start and end time for net_usage_rate_average
      stats_counter = 0
      (expected_stats_period_start + 20.seconds..expected_stats_period_end).step_value(20.seconds).each do |timestamp|
        expect(@metrics_by_ts[timestamp.iso8601].try(:net_usage_rate_average)).not_to eq nil
        stats_counter += 1
      end

      # check that 20s block is not interrupted between start and end time for disk_usage_rate_average
      stats_counter = 0
      (expected_stats_period_start + 20.seconds..expected_stats_period_end).step_value(20.seconds).each do |timestamp|
        expect(@metrics_by_ts[timestamp.iso8601].try(:disk_usage_rate_average)).not_to eq nil
        stats_counter += 1
      end

      # check that 20s block is not interrupted between start and end time for cpu_usage_rate_average
      stats_counter = 0
      (expected_stats_period_start + 20.seconds..expected_stats_period_end).step_value(20.seconds).each do |timestamp|
        expect(@metrics_by_ts[timestamp.iso8601].try(:cpu_usage_rate_average)).not_to eq nil
        stats_counter += 1
      end
    end
  end

  context "2 collection periods total, there is data hole between periods" do
    it "verifies that hole in the data is logged, corrupted data is logged and no other warnings are logged" do
      # Hole in the data is logged
      expect($log).to receive(:warn).with(/expected to get data as of/).exactly(:once)
      # Corrupted data is logged
      expect($log).to receive(:warn).with(/Distance of the multiple streams of data is invalid/).exactly(:once)
      # No to other warnings should be logged
      expect($log).not_to receive(:warn)

      # sending no collection period overlap will cause hole in the data
      capture_data('2013-08-28T11:56:00Z', nil)
    end
  end

  def capture_data(second_collection_period_start, collection_overlap_period)
    # 1.collection period, save all metrics
    allow(@metering).to receive(:get_statistics) do |name, _options|
      first_collection_period = filter_statistics(@mock_stats_data.get_statistics(name,
                                                                                  "multiple_collection_periods"),
                                                  '<=',
                                                  second_collection_period_start)

      OpenstackApiResult.new(first_collection_period)
    end

    allow(@vm).to receive(:state_changed_on).and_return(second_collection_period_start)
    @vm.perf_capture_realtime(Time.parse('2013-08-28T11:01:40Z').utc, Time.parse(second_collection_period_start).utc)

    # 2.collection period, save all metrics
    allow(@metering).to receive(:get_statistics) do |name, _options|
      second_collection_period = filter_statistics(@mock_stats_data.get_statistics(name,
                                                                                   "multiple_collection_periods"),
                                                   '>',
                                                   second_collection_period_start,
                                                   collection_overlap_period)

      OpenstackApiResult.new(second_collection_period)
    end

    allow(@vm).to receive(:state_changed_on).and_return(second_collection_period_start)
    @vm.perf_capture_realtime(Time.parse(second_collection_period_start).utc, Time.parse('2013-08-28T14:02:00Z').utc)

    @metrics_by_ts = {}
    @vm.metrics.each do |x|
      @metrics_by_ts[x.timestamp.iso8601] = x
    end

    # grab read bytes and write bytes data, these values are pulled directly from
    # spec/tools/openstack_data/openstack_perf_data/multiple_collection_periods.yml
    @read_bytes = @mock_stats_data.get_statistics("network.incoming.bytes",
                                                  "multiple_collection_periods")

    @write_bytes = @mock_stats_data.get_statistics("network.outgoing.bytes",
                                                   "multiple_collection_periods")
  end

  def filter_statistics(stats, op, date, subtract_by = nil)
    filter_date  = parse_datetime(date)
    filter_date -= subtract_by if subtract_by
    stats.select { |x| x['period_end'].send(op, filter_date) }
  end

  def api_time_as_utc(api_result)
    period_end = api_result["period_end"]
    parse_datetime(period_end)
  end

  def parse_datetime(datetime)
    datetime << "Z" if datetime.size == 19
    Time.parse(datetime).utc
  end

  context "handles archived container entities" do
    it "get the correct queue name and zone from archived container entities" do
      ems = FactoryGirl.create(:ems_openshift, :name => 'OpenShiftProvider')
      group = FactoryGirl.create(:container_group, :name => "group", :ext_management_system => ems)
      container = FactoryGirl.create(:container,
                                     :name                  => "container",
                                     :container_group       => group,
                                     :ext_management_system => ems)
      project = FactoryGirl.create(:container_project,
                                   :name                  => "project",
                                   :ext_management_system => ems)
      container.disconnect_inv
      group.disconnect_inv
      project.disconnect_inv

      expect(container.queue_name_for_metrics_collection).to eq ems.metrics_collector_queue_name
      expect(group.queue_name_for_metrics_collection).to eq ems.metrics_collector_queue_name
      expect(project.queue_name_for_metrics_collection).to eq ems.metrics_collector_queue_name

      expect(container.my_zone).to eq ems.my_zone
      expect(group.my_zone).to eq ems.my_zone
      expect(project.my_zone).to eq ems.my_zone
    end
  end
end
