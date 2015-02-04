require "spec_helper"

describe Metric::CiMixin::Capture::OpenstackInfra do
  require File.expand_path(File.join(File.dirname(__FILE__),
                                     %w(.. .. .. .. tools openstack_data openstack_data_test_helper)))

  before :each do
    MiqRegion.seed
    _guid, _server, @zone = EvmSpecHelper.create_guid_miq_server_zone

    @mock_meter_list = OpenstackMeterListData.new
    @mock_stats_data = OpenstackMetricStatsData.new

    @ems_openstack = FactoryGirl.create(:ems_openstack_infra, :zone => @zone)
    @ems_openstack.stub(:list_meters).and_return(
      OpenstackApiResult.new(@mock_meter_list.list_meters("metadata_counters")))

    @host = FactoryGirl.create(:host_openstack_infra, :ext_management_system => @ems_openstack)
    @host.stub(:perf_init_openstack).and_return(@ems_openstack)
  end

  context "with standard interval data" do
    before :each do
      @ems_openstack.stub(:get_statistics) do |name, _options|
        OpenstackApiResult.new(@mock_stats_data.get_statistics(name))
      end
    end

    it "treats openstack timestamp as UTC" do
      ts_as_utc = api_time_as_utc(@mock_stats_data.get_statistics("hardware.system_stats.cpu.util").last)
      _counters, values_by_id_and_ts = @host.perf_collect_metrics_openstack("perf_capture_data_openstack_infra",
                                                                            "realtime")
      ts = Time.parse(values_by_id_and_ts[@host.ems_ref].keys.sort.last)

      ts_as_utc.should eq ts
    end

    it "translates cumulative meters into discrete values" do
      counter_info = Metric::Capture::OpenstackInfra::COUNTER_INFO.find do |c|
        c[:vim_style_counter_key] == "disk_usage_rate_average"
      end

      # the next 4 steps are test comparison data setup

      # 1. grab the 3rd-to-last, 2nd-to-last and last API results for disk read/writes
      # need 3rd-to-last to get the interval for the 2nd-to-last values
      *_, read_bytes_prev, read_bytes1, read_bytes2 = @mock_stats_data.get_statistics(
          "hardware.system_stats.io.incoming.blocks")
      *_, write_bytes_prev, write_bytes1, write_bytes2 = @mock_stats_data.get_statistics(
          "hardware.system_stats.io.outgoing.blocks")

      read_ts_prev = api_time_as_utc(read_bytes_prev)
      write_ts_prev = api_time_as_utc(write_bytes_prev)
      read_val_prev = read_bytes_prev["avg"]
      write_val_prev = write_bytes_prev["avg"]

      # 2. calculate the disk_usage_rate_average for the 2nd-to-last API result
      read_ts1 = api_time_as_utc(read_bytes1)
      read_val1 = read_bytes1["avg"]
      write_ts1 = api_time_as_utc(write_bytes1)
      write_val1 = write_bytes1["avg"]
      disk_val1 = counter_info[:calculation].call(
        {
          "hardware.system_stats.io.incoming.blocks" => read_val1 - read_val_prev,
          "hardware.system_stats.io.outgoing.blocks" => write_val1 - write_val_prev
        },
        "hardware.system_stats.io.incoming.blocks" => read_ts1 - read_ts_prev,
        "hardware.system_stats.io.outgoing.blocks" => write_ts1 - write_ts_prev
        )

      # 3. calculate the disk_usage_rate_average for the last API result
      read_ts2 = api_time_as_utc(read_bytes2)
      read_val2 = read_bytes2["avg"]
      write_ts2 = api_time_as_utc(write_bytes2)
      write_val2 = write_bytes2["avg"]
      disk_val2 = counter_info[:calculation].call(
        {
          "hardware.system_stats.io.incoming.blocks" => read_val2 - read_val1,
          "hardware.system_stats.io.outgoing.blocks" => write_val2 - write_val1
        },
        "hardware.system_stats.io.incoming.blocks" => read_ts2 - read_ts1,
        "hardware.system_stats.io.outgoing.blocks" => write_ts2 - write_ts1
        )

      # get the actual values from the method
      _, values_by_id_and_ts = @host.perf_collect_metrics_openstack("perf_capture_data_openstack_infra", "realtime")
      values_by_ts = values_by_id_and_ts[@host.ems_ref]

      # make sure that the last calculated value is the same as the discrete values
      # calculated in step #2 and #3 above
      *_, result = values_by_ts

      read_ts1_period = api_time_as_utc(read_bytes1)
      read_ts2_period = api_time_as_utc(read_bytes2)
      result[read_ts1_period.iso8601]["disk_usage_rate_average"].should eq disk_val1
      result[read_ts2_period.iso8601]["disk_usage_rate_average"].should eq disk_val2
    end
  end

  context "with irregular interval data" do
    before do
      @ems_openstack.stub(:get_statistics) do |name, _options|
        OpenstackApiResult.new(@mock_stats_data.get_statistics(name, "irregular_interval"))
      end

      preload_data
    end

    def preload_data
      @counter_info = Metric::Capture::OpenstackInfra::COUNTER_INFO.find do |c|
        c[:vim_style_counter_key] == "disk_usage_rate_average"
      end

      # grab read bytes and write bytes data, these values are pulled directly from
      # spec/tools/openstack_data/openstack_perf_data/irregular_interval.yml
      @read_bytes = @mock_stats_data.get_statistics("hardware.system_stats.io.incoming.blocks", "irregular_interval")
      @write_bytes = @mock_stats_data.get_statistics("hardware.system_stats.io.outgoing.blocks", "irregular_interval")

      _, values_by_id_and_ts = @host.perf_collect_metrics_openstack("perf_capture_data_openstack_infra", "realtime")
      @values_by_ts = values_by_id_and_ts[@host.ems_ref]
      @ts_keys = @values_by_ts.keys.sort
    end
    ###################################################################################################################
    # DESCRIPTION FOR: disk_usage_rate_average tests
    # MAIN SCENARIOS :
    # Check that samples are correctly normalized into 20s intervals.
    #
    # the first two openstack metrics should look like:
    #   ts: 2013-08-28T11:01:09 => hardware.system_stats.cpu.util: 50
    #   ts: 2013-08-28T11:02:12 => hardware.system_stats.cpu.util: 100
    #   ts: 2013-08-28T11:03:15 => hardware.system_stats.cpu.util: 25
    #   ts: 2013-08-28T11:04:18 => hardware.system_stats.cpu.util: 50
    #   ts: 2013-08-28T11:05:21 => hardware.system_stats.cpu.util: 20
    #
    # after capture and processing, the first six statistics should look like:
    #   ts: 2013-08-28T11:01:40 => cpu_usage_rate_average: 100
    #   ts: 2013-08-28T11:02:00 => cpu_usage_rate_average: 100
    #   ts: 2013-08-28T11:02:20 => cpu_usage_rate_average: 100
    #   ts: 2013-08-28T11:02:40 => cpu_usage_rate_average: 25
    #   ts: 2013-08-28T11:03:00 => cpu_usage_rate_average: 25
    #   ts: 2013-08-28T11:03:20 => cpu_usage_rate_average: 25
    #   ts: 2013-08-28T11:03:40 => cpu_usage_rate_average: 50
    #   etc..
    #
    # note:
    #   In interval (last_ts, ts> we are filling value on ts, the first value is always stored in previous Metrics
    #   collection period. In this example, we are skipping period:
    #   <2013-08-28T11:01:00, 2013-08-28T11:01:20> - where sample with duration_period 2013-08-28T11:01:09 fits
    #   and we are starting with period:
    #   <2013-08-28T11:01:20, 2013-08-28T11:01:40>
    #
    it "normalizes irregular intervals of cpu_usage_rate_average into 20sec intervals" do
      avg_stat1 = 100
      avg_stat2 = 25
      avg_stat3 = 50
      avg_stat4 = 20

      # First 3 stats are nil, cause hardware.system_stats.io.outgoing.blocks starts at "2013-08-28T11:00:20". All
      # the stats are collected together by capturing algorithm.
      (0..2).each { |i| @values_by_ts[@ts_keys[i]]["cpu_usage_rate_average"].should eq nil }
      # ensure that the next three statistics match avg_stat1
      (3..5).each { |i| @values_by_ts[@ts_keys[i]]["cpu_usage_rate_average"].should eq avg_stat1 }
      # ensure that the next three statistics match avg_stat2
      (6..8).each { |i| @values_by_ts[@ts_keys[i]]["cpu_usage_rate_average"].should eq avg_stat2 }
      # ensure that the next three statistics match avg_stat3
      (9..11).each { |i| @values_by_ts[@ts_keys[i]]["cpu_usage_rate_average"].should eq avg_stat3 }
      # ensure that the next 4 statistics match avg_stat4
      (12..15).each { |i| @values_by_ts[@ts_keys[i]]["cpu_usage_rate_average"].should eq avg_stat4 }
    end

    it "makes sure cpu_usage_rate_average stats continuous block of 20s is correct" do
      # get start and end date are as expected
      expected_stats_period_start = parse_datetime('2013-08-28T11:01:40')
      expected_stats_period_end = parse_datetime('2013-08-28T11:11:00')

      # check that 20s block is not interrupted between start and end time, and that count of 20s block is correct
      stats_counter = 0
      (expected_stats_period_start + 20.seconds..expected_stats_period_end).step_value(20.seconds).each do |timestamp|
        @values_by_ts[timestamp.iso8601].try(:[], "disk_usage_rate_average").should_not eq nil
        stats_counter += 1
      end

      # check total number of 20s blocks
      stats_counter.should eq 28
    end

    ###################################################################################################################
    # DESCRIPTION FOR: disk_usage_rate_average tests
    # MAIN SCENARIOS :
    # "hardware.system_stats.io.incoming.blocks", "hardware.system_stats.io.outgoing.blocks" are two streams of data
    # whose values should be summed together and divided by intervals between their last values. These streams have the
    # same size of samples, but are not aligned. We are checking if we are able to align values of those streams and
    # compute stats properly.
    #
    # In reality, in most cases, samples should be aligned or max 20s far (one period far). If the samples of each
    # stream are too far, it can point problems on server(bad settings or need for Ceilometer to scale). In this example
    # we have streams moved around 1 minute from each other.
    #
    # ASCII DIAGRAM: streams a and b are not aligned, we need to save stream with data buckets containing samples from
    # both streams
    # NOTE: diagram is just for explaining of the process, real data are different
    #
    # stream a:         ---------1a--------2a--------3a----------4a---
    # stream b:         ------1b--------2b---------3b----------4b------
    # saved stream:           1---------2--- ------3-----------4
    #
    # the first three read.bytes metrics
    #   ts: 2013-08-28T11:01:09 => read_bytes: 20
    #   ts: 2013-08-28T11:03:12 => read_bytes: 35
    #   ts: 2013-08-28T11:05:15 => read_bytes: 48
    #   ts: 2013-08-28T11:07:18 => read_bytes: 53
    #   ts: 2013-08-28T11:09:21 => read_bytes: 69
    #
    # the first three write bytes metrics
    #   ts: 2013-08-28T11:00:09 => write_bytes: 500
    #   ts: 2013-08-28T11:02:12 => write_bytes: 691
    #   ts: 2013-08-28T11:04:15 => write_bytes: 753
    #   ts: 2013-08-28T11:06:18 => write_bytes: 836
    #   ts: 2013-08-28T11:08:21 => write_bytes: 935
    #
    # Data should be collected into this buckets (last_period and period)
    # First:  last_period: 2013-08-28T11:01:20
    #         last_period: 2013-08-28T11:00:20
    #         period     : 2013-08-28T11:03:20
    #         period     : 2013-08-28T11:02:20
    #
    # Second: last_period: 2013-08-28T11:03:12
    #         last_period: 2013-08-28T11:02:12
    #         period     : 2013-08-28T11:05:20
    #         period     : 2013-08-28T11:04:20
    # Third:  etc.
    #
    # after capture and processing, the first six statistics should look like:
    #   ts: from 2013-08-28T11:01:40Z to 2013-08-28T11:03:20Z => disk_usage_rate_average: 0.0016355436991869919
    #       total 6 of 20s periods
    #   ts: from 2013-08-28T11:03:40Z to 2013-08-28T11:05:20Z => disk_usage_rate_average: 0.0005954649390243902
    #       total 6 of 20s periods
    #   ts: from 2013-08-28T11:05:40Z to 2013-08-28T11:07:20Z => disk_usage_rate_average: 0.0006986788617886179
    #       total 6 of 20s periods
    #   ts: from 2013-08-28T11:07:40Z to 2013-08-28T11:09:40Z => disk_usage_rate_average: 0.0009130462398373985
    #       total 7 of 20s periods
    #   etc..
    #
    # note:
    #   In interval (last_ts, ts> we are filling value on ts, the first value is always stored in previous Metrics
    #   collection period. In this example, we are skipping period:
    #   <2013-08-28T11:01:00, 2013-08-28T11:01:20> - where sample with duration_period 2013-08-28T11:01:09 fits
    #   and we are starting with period:
    #   <2013-08-28T11:01:20, 2013-08-28T11:03:40>
    #
    it "computes diffs of the first 4 values of disk_usage_rate_average values correctly" do
      # Make the computations os stats
      avg_stat1_manual = (
      (35  - 20)  / (parse_datetime('2013-08-28T11:03:12') - parse_datetime('2013-08-28T11:01:09')).to_f +
          (691 - 500) / (parse_datetime('2013-08-28T11:02:12') - parse_datetime('2013-08-28T11:00:09')).to_f
      )
      avg_stat4_manual = (
      (69  - 53)  / (parse_datetime('2013-08-28T11:09:21') - parse_datetime('2013-08-28T11:07:18')).to_f +
          (935 - 836) / (parse_datetime('2013-08-28T11:08:21') - parse_datetime('2013-08-28T11:06:18')).to_f
      )

      avg_stat1_computed_elsewhere = 1.6747967479674797
      avg_stat1 = make_calculation(@counter_info, "hardware.system_stats.io.incoming.blocks",
                                   "hardware.system_stats.io.outgoing.blocks", @write_bytes, @read_bytes, 0, 1)
      avg_stat2_computed_elsewhere = 0.6097560975609756
      avg_stat2 = make_calculation(@counter_info, "hardware.system_stats.io.incoming.blocks",
                                   "hardware.system_stats.io.outgoing.blocks", @write_bytes, @read_bytes, 1, 2)
      avg_stat3_computed_elsewhere = 0.7154471544715447
      avg_stat3 = make_calculation(@counter_info, "hardware.system_stats.io.incoming.blocks",
                                   "hardware.system_stats.io.outgoing.blocks", @write_bytes, @read_bytes, 2, 3)
      avg_stat4_computed_elsewhere = 0.934959349593496
      avg_stat4 = make_calculation(@counter_info, "hardware.system_stats.io.incoming.blocks",
                                   "hardware.system_stats.io.outgoing.blocks", @write_bytes, @read_bytes, 3, 4)

      # ensure computations are equal
      avg_stat1_manual.should eq avg_stat1_computed_elsewhere
      avg_stat4_manual.should eq avg_stat4_computed_elsewhere
      avg_stat1.should eq avg_stat1_computed_elsewhere
      avg_stat2.should eq avg_stat2_computed_elsewhere
      avg_stat3.should eq avg_stat3_computed_elsewhere
      avg_stat4.should eq avg_stat4_computed_elsewhere
    end

    it "aligns not aligned data of the disk_usage_rate_average counters and computes stats correctly" do
      # make computation of stats for comparison
      avg_stat1 = make_calculation(@counter_info, "hardware.system_stats.io.incoming.blocks",
                                   "hardware.system_stats.io.outgoing.blocks", @write_bytes, @read_bytes, 0, 1)
      avg_stat2 = make_calculation(@counter_info, "hardware.system_stats.io.incoming.blocks",
                                   "hardware.system_stats.io.outgoing.blocks", @write_bytes, @read_bytes, 1, 2)
      avg_stat3 = make_calculation(@counter_info, "hardware.system_stats.io.incoming.blocks",
                                   "hardware.system_stats.io.outgoing.blocks", @write_bytes, @read_bytes, 2, 3)
      avg_stat4 = make_calculation(@counter_info, "hardware.system_stats.io.incoming.blocks",
                                   "hardware.system_stats.io.outgoing.blocks", @write_bytes, @read_bytes, 3, 4)
      avg_stat5 = make_calculation(@counter_info, "hardware.system_stats.io.incoming.blocks",
                                   "hardware.system_stats.io.outgoing.blocks", @write_bytes, @read_bytes, 4, 5)
      avg_stat6 = make_calculation(@counter_info, "hardware.system_stats.io.incoming.blocks",
                                   "hardware.system_stats.io.outgoing.blocks", @write_bytes, @read_bytes, 5, 6)
      avg_stat7 = make_calculation(@counter_info, "hardware.system_stats.io.incoming.blocks",
                                   "hardware.system_stats.io.outgoing.blocks", @write_bytes, @read_bytes, 6, 7)

      # ensure that the first 6 statistics match avg_stat1
      (0..5).each { |i| @values_by_ts[@ts_keys[i]]["disk_usage_rate_average"].should eq avg_stat1 }
      # ensure that the next 6 statistics match avg_stat2
      (6..11).each { |i| @values_by_ts[@ts_keys[i]]["disk_usage_rate_average"].should eq avg_stat2 }
      # ensure that the next 6 statistics match avg_stat3
      (12..17).each { |i| @values_by_ts[@ts_keys[i]]["disk_usage_rate_average"].should eq avg_stat3 }
      # ensure that the next 7 statistics match avg_stat4
      (18..24).each { |i| @values_by_ts[@ts_keys[i]]["disk_usage_rate_average"].should eq avg_stat4 }
      # ensure that the next 6 statistics match avg_stat5
      (25..30).each { |i| @values_by_ts[@ts_keys[i]]["disk_usage_rate_average"].should eq avg_stat5 }
      # ensure that the next 6 statistics match avg_stat6
      (31..36).each { |i| @values_by_ts[@ts_keys[i]]["disk_usage_rate_average"].should eq avg_stat6 }
      # ensure that the next 6 statistics match avg_stat7
      (37..42).each { |i| @values_by_ts[@ts_keys[i]]["disk_usage_rate_average"].should eq avg_stat7 }
    end

    it "checks this collection period has right count of samples saved" do
      # ensure total number of stats is correct
      @ts_keys.count.should eq 43
    end

    it "makes sure disk_usage_rate_average stats continuous block of 20s is correct" do
      # get start and end date as expected
      expected_stats_period_start = parse_datetime('2013-08-28 11:00:20')
      expected_stats_period_end = parse_datetime('2013-08-28 11:14:40Z')

      # check that 20s block is not interrupted between start and end time, and that count of 20s block is correct
      stats_counter = 0
      (expected_stats_period_start + 20.seconds..expected_stats_period_end).step_value(20.seconds).each do |timestamp|
        @values_by_ts[timestamp.iso8601].try(:[], "disk_usage_rate_average").should_not eq nil
        stats_counter += 1
      end

      # check total number of 20s blocks
      stats_counter.should eq 43
    end

    it "makes sure start time and end time of collection periods are correct" do
      # get start time and end time of the whole 20s stream
      stats_period_start = [api_time_as_utc(@read_bytes.first), api_time_as_utc(@write_bytes.first)].min
      stats_period_end   = [api_time_as_utc(@read_bytes.last), api_time_as_utc(@write_bytes.last)].min

      # check start and end date are as expected
      expected_stats_period_start = parse_datetime('2013-08-28 11:00:20')
      expected_stats_period_end   = parse_datetime('2013-08-28 11:14:40Z')

      stats_period_start.should eq expected_stats_period_start
      stats_period_end.should   eq expected_stats_period_end
    end
  end

  #####################################################################################################################
  # These constants are used in both 1. collection period and 2.collection period. These constants should make sure of
  # correct connection of these two periods of net_usage_rate_average
  NET_SECOND_COLLECTION_PERIOD_START                  = '2013-08-28T12:02:00'
  # This should be double of the period Ceilometer has set for collecting data.
  NET_COLLECTION_OVERLAP_PERIOD                       = 20.minutes
  NET_LAST_VALUE_OF_FIRST_COLLECTING_PERIOD           = 4.403654485049834
  NET_LAST_VALUE_OF_FIRST_COLLECTING_PERIOD_TIMESTAMP = '2013-08-28 11:51:40Z'

  context "1. collection period from 2 collection periods total of net_usage_rate_average, end of this period has "\
          "incomplete stat" do
    before do
      @ems_openstack.stub(:get_statistics) do |name, _options|
        first_collection_period = filter_statistics(@mock_stats_data.get_statistics(name,
                                                                                    "multiple_collection_periods"),
                                                    '<=',
                                                    NET_SECOND_COLLECTION_PERIOD_START)

        OpenstackApiResult.new(first_collection_period)
      end

      preload_data
    end

    def preload_data
      @counter_info = Metric::Capture::OpenstackInfra::COUNTER_INFO.find do |c|
        c[:vim_style_counter_key] == "net_usage_rate_average"
      end

      # grab read bytes and write bytes data, these values are pulled directly from
      # spec/tools/openstack_data/openstack_perf_data/multiple_collection_periods.yml
      @read_bytes =  filter_statistics(@mock_stats_data.get_statistics("hardware.network.ip.incoming.datagrams",
                                                                       "multiple_collection_periods"),
                                       '<=',
                                       NET_SECOND_COLLECTION_PERIOD_START)

      @write_bytes = filter_statistics(@mock_stats_data.get_statistics("hardware.network.ip.outgoing.datagrams",
                                                                       "multiple_collection_periods"),
                                       '<=',
                                       NET_SECOND_COLLECTION_PERIOD_START)

      _, values_by_id_and_ts = @host.perf_collect_metrics_openstack("perf_capture_data_openstack_infra", "realtime")
      @values_by_ts = values_by_id_and_ts[@host.ems_ref]
      @ts_keys = @values_by_ts.keys.sort
    end

    ###################################################################################################################
    # DESCRIPTION FOR: net_usage_rate_average
    # MAIN SCENARIOS :
    # "hardware.network.ip.incoming.datagrams", "hardware.network.ip.incoming.datagrams" are two streams of data whose
    # values should be summed together and divided by intervals between their last values. We should observe in these
    # tests, that incomplete data buckets (data from all streams) from borders of collection periods should be thrown
    # away and collected in next period. Incomplete data buckets from middle of the stream should be replaced by next
    # complete bucket.
    #
    # 1. The streams has different sizes, that means Ceilometer was not able to collect data for both streams at some
    # point. We should verify that these incomplete values (we have value only from one stream) are thrown away, and
    # the whole period should be filled with next complete value (that has value from both streams). Also warning that
    # data are corrupted should be raised.
    #
    # ASCII DIAGRAM: streams a and b, value for for 4b is missing, 4a should be thrown away and replaced by 5, which is
    # complete. The whole (3, 5> interval will be filled with value of 5.
    # NOTE: diagram is just for explaining of the process, real data are different
    #
    # stream a:         ---------1a-----2a-------------3a----------4a--------5a
    # stream b:         ------1b----------2b--------3b--------------------5b
    # saved stream:           1---------2-----------3------------------------5
    #
    # 2. We will observe collecting of the the data in 2 collection periods. When in first period, the last stats value
    # will have value from only one stream, so it should be thrown away. Since it's in the end of the collection period,
    # the stats will not be filled in that period.
    #
    # ASCII DIAGRAM: streams a and b, 1. collection period is missing sample 3a, so the whole (2, 3> period should not
    # be saved. Then 2. collection period start is moved default 20 minutes back, so this period is able to save the
    # missing (2, 3> period. We need to be able to obtain sample number 2, for computing last_value for diff.
    # NOTE: diagram is just for explaining of the process, real data are different
    #
    # stream a 1.collection period:    --------------1a-----2a----------------
    # stream b 1.collection period:    ----------1b-----------2b----------3b--
    # stream a 2.collection period:                  1a-----2a----------------3a-------4a--------5a-
    # stream b 2.collection period:                  ---------2b----------3b-------------------5b---
    # saved stream 1.collection period:          1----------2
    # saved stream 2.collection period:                      -------------3--------------------5
    #
    # 3. Continuation of the 2.scenario, the last period, that has not been filled, should be filled in next collection
    # period. Cause startime is always 20minutes (default setting) back into last collection period.
    #
    # ASCII DIAGRAM shown in step 2, 2.collection period
    it "checks that the net_usage_rate_average has aligned data and computed stats correctly" do
      # make computation of stats for comparison
      avg_stat1 = make_calculation(@counter_info, "hardware.network.ip.incoming.datagrams",
                                   "hardware.network.ip.outgoing.datagrams", @write_bytes, @read_bytes, 0, 1)
      avg_stat2 = make_calculation(@counter_info, "hardware.network.ip.incoming.datagrams",
                                   "hardware.network.ip.outgoing.datagrams", @write_bytes, @read_bytes, 1, 2)
      avg_stat3 = make_calculation(@counter_info, "hardware.network.ip.incoming.datagrams",
                                   "hardware.network.ip.outgoing.datagrams", @write_bytes, @read_bytes, 2, 3)
      avg_stat4 = make_calculation(@counter_info, "hardware.network.ip.incoming.datagrams",
                                   "hardware.network.ip.outgoing.datagrams", @write_bytes, @read_bytes, 3, 4)
      avg_stat5 = make_calculation(@counter_info, "hardware.network.ip.incoming.datagrams",
                                   "hardware.network.ip.outgoing.datagrams", @write_bytes, @read_bytes, 4, 5)

      # ensure that the first 30 statistics match avg_stat1
      (0..29).each { |i| @values_by_ts[@ts_keys[i]]["net_usage_rate_average"].should eq avg_stat1 }
      # ensure that the next 30 statistics match avg_stat2
      (30..59).each { |i| @values_by_ts[@ts_keys[i]]["net_usage_rate_average"].should eq avg_stat2 }
      # ensure that the next 30 statistics match avg_stat3
      (60..89).each { |i| @values_by_ts[@ts_keys[i]]["net_usage_rate_average"].should eq avg_stat3 }
      # ensure that the next 31 statistics match avg_stat4
      (90..120).each { |i| @values_by_ts[@ts_keys[i]]["net_usage_rate_average"].should eq avg_stat4 }
      # ensure that the next 30 statistics match avg_stat5
      (121..150).each { |i| @values_by_ts[@ts_keys[i]]["net_usage_rate_average"].should eq avg_stat5 }
    end

    it "checks that the net_usage_rate_average should have last incomplete stat not saved" do
      # Ensure that the last 30 statistics match nil. This happens because net usage stat has been incomplete, so we s
      # tore nil values, these nil values should be rewritten in next collection period.
      (151..180).each { |i| @values_by_ts[@ts_keys[i]]["net_usage_rate_average"].should eq nil }
    end

    it "checks this collection period has right count of samples saved" do
      # ensure total number of stats is correct, 151 data stats and 30 nil stats
      @ts_keys.count.should eq 181
    end

    it "tests that last computed statistic has the right value" do
      avg_stat5 = make_calculation(@counter_info, "hardware.network.ip.incoming.datagrams",
                                   "hardware.network.ip.outgoing.datagrams", @write_bytes, @read_bytes, 4, 5)

      # Test that last value of 1. collection period is this. This test continues in 2. collection period test. This
      # value has to be different to first value of 2.collection period
      avg_stat5.should eq NET_LAST_VALUE_OF_FIRST_COLLECTING_PERIOD
    end

    it "make sure disk_usage_rate_average stats continuos block of 20s is correct" do
      # get start and end date as expected
      expected_stats_period_start = parse_datetime('2013-08-28 11:01:20')
      expected_stats_period_end = parse_datetime(NET_LAST_VALUE_OF_FIRST_COLLECTING_PERIOD_TIMESTAMP)

      # check that 20s block is not interrupted between start and end time, and that count of 20s block is correct
      stats_counter = 0
      (expected_stats_period_start + 20.seconds..expected_stats_period_end).step_value(20.seconds).each do |timestamp|
        @values_by_ts[timestamp.iso8601].try(:[], "net_usage_rate_average").should_not eq nil
        stats_counter += 1
      end

      # check total number of 20s blocks
      stats_counter.should eq 151
    end

    it "makes sure start time and end time of collection period are correct" do
      # get start time and end time of the whole 20s stream
      stats_period_start = [api_time_as_utc(@read_bytes.first), api_time_as_utc(@write_bytes.first)].min
      # @read_bytes last doesn't have pair sample in write bytes, so last sample is on index -2
      stats_period_end = [api_time_as_utc(@read_bytes[-2]), api_time_as_utc(@write_bytes.last)].min

      # check start and end date are as expected
      expected_stats_period_start = parse_datetime('2013-08-28 11:01:20')
      expected_stats_period_end = parse_datetime(NET_LAST_VALUE_OF_FIRST_COLLECTING_PERIOD_TIMESTAMP)
      stats_period_start.should eq expected_stats_period_start
      stats_period_end.should eq expected_stats_period_end
    end
  end

  context "2. collection period from 2 collection periods total of net_usage_rate_average, start and middle of "\
          "this period has one incomplete stat" do
    before do
      @ems_openstack.stub(:get_statistics) do |name, _options|
        second_collection_period = filter_statistics(@mock_stats_data.get_statistics(name,
                                                                                     "multiple_collection_periods"),
                                                     '>',
                                                     NET_SECOND_COLLECTION_PERIOD_START,
                                                     NET_COLLECTION_OVERLAP_PERIOD)

        OpenstackApiResult.new(second_collection_period)
      end

      @orig_log = $log
      $log = double.as_null_object

      preload_data
    end

    after do
      $log = @orig_log
    end

    def preload_data
      @counter_info = Metric::Capture::OpenstackInfra::COUNTER_INFO.find do |c|
        c[:vim_style_counter_key] == "net_usage_rate_average"
      end

      # grab read bytes and write bytes data, these values are pulled directly from
      # spec/tools/openstack_data/openstack_perf_data/multiple_collection_periods.yml
      @read_bytes =  filter_statistics(@mock_stats_data.get_statistics("hardware.network.ip.incoming.datagrams",
                                                                       "multiple_collection_periods"),
                                       '>',
                                       NET_SECOND_COLLECTION_PERIOD_START,
                                       NET_COLLECTION_OVERLAP_PERIOD)

      @write_bytes = filter_statistics(@mock_stats_data.get_statistics("hardware.network.ip.outgoing.datagrams",
                                                                       "multiple_collection_periods"),
                                       '>',
                                       NET_SECOND_COLLECTION_PERIOD_START,
                                       NET_COLLECTION_OVERLAP_PERIOD)
      # Drop fist element of write bytes, as that is an incomplete stat
      @write_bytes.shift
      # Drop pre last element of write bytes cause it doesn't have pair sample, therefore it is an incomplete stat
      @write_bytes.delete_at(-2)

      _, values_by_id_and_ts = @host.perf_collect_metrics_openstack("perf_capture_data_openstack_infra", "realtime")
      @values_by_ts = values_by_id_and_ts[@host.ems_ref]
      @ts_keys = @values_by_ts.keys.sort
    end

    ###################################################################################################################
    # Complete scenario doc is placed in first collection period

    it "checks that the net_usage_rate_average has aligned data and computed stats correctly" do
      # make computation of stats for comparison
      avg_stat1 = make_calculation(@counter_info, "hardware.network.ip.incoming.datagrams",
                                   "hardware.network.ip.outgoing.datagrams", @write_bytes, @read_bytes, 0, 1)
      avg_stat2 = make_calculation(@counter_info, "hardware.network.ip.incoming.datagrams",
                                   "hardware.network.ip.outgoing.datagrams", @write_bytes, @read_bytes, 1, 2)
      avg_stat3 = make_calculation(@counter_info, "hardware.network.ip.incoming.datagrams",
                                   "hardware.network.ip.outgoing.datagrams", @write_bytes, @read_bytes, 2, 3)
      avg_stat4 = make_calculation(@counter_info, "hardware.network.ip.incoming.datagrams",
                                   "hardware.network.ip.outgoing.datagrams", @write_bytes, @read_bytes, 3, 4)

      # ensure that the next 30 statistics match avg_stat1
      (21..50).each { |i| @values_by_ts[@ts_keys[i]]["net_usage_rate_average"].should eq avg_stat1 }
      # ensure that the next 30 statistics match avg_stat2
      (51..80).each { |i| @values_by_ts[@ts_keys[i]]["net_usage_rate_average"].should eq avg_stat2 }
      # ensure that the next 30 statistics match avg_stat3
      (81..110).each { |i| @values_by_ts[@ts_keys[i]]["net_usage_rate_average"].should eq avg_stat3 }
      # ensure that the next 60 statistics match avg_stat4
      # This test assures us that this value fills the empty space caused by corrupted data with missing stat.
      (111..170).each { |i| @values_by_ts[@ts_keys[i]]["net_usage_rate_average"].should eq avg_stat4 }
    end

    it "checks that the net_usage_rate_average should have last incomplete stat not saved" do
      # Ensure that the first 21 statistics match nil. This happens because there is one more stat of
      # hardware.system_stats.cpu.util, but net usage stat has been incomplete, so we store nil values, those nil
      # values has been filled with the right value in previous collection period.
      # !!!!!!! It's up to saving mechanism to not overwrite the old values with nil. !!!!!!!!!!!
      (0..20).each { |i| @values_by_ts[@ts_keys[i]]["net_usage_rate_average"].should eq nil }
    end

    it "checks this collection period has right count of samples saved" do
      # ensure total number of stats is correct, 150 data stats and 21 nil stats
      @ts_keys.count.should eq 171
    end

    it "checks that last sample of 1. collection period is different to first sample of 2. collection period" do
      # make computation of stats for comparison
      avg_stat1 = make_calculation(@counter_info, "hardware.network.ip.incoming.datagrams",
                                   "hardware.network.ip.outgoing.datagrams", @write_bytes, @read_bytes, 0, 1)

      avg_stat1.should_not eq NET_LAST_VALUE_OF_FIRST_COLLECTING_PERIOD
    end

    it "there is missing stat in the middle of the period, make sure we log warning of corrupted data exactly once" do
      # should fail twice for mem_usage and net_usage
      $log.should_receive(:warn).with(/Distance of the multiple streams of data is invalid/).exactly(:twice)
      @host.perf_collect_metrics_openstack("perf_capture_data_openstack_infra", "realtime")
    end

    it "make sure disk_usage_rate_average stats continuos block of 20s is correct" do
      expected_stats_period_start = parse_datetime(NET_LAST_VALUE_OF_FIRST_COLLECTING_PERIOD_TIMESTAMP)
      expected_stats_period_end = parse_datetime('2013-08-28 12:41:40Z')

      # check that 20s block is not interrupted between start and end time, and that count of 20s block is correct
      stats_counter = 0
      (expected_stats_period_start + 20.seconds..expected_stats_period_end).step_value(20.seconds).each do |timestamp|
        @values_by_ts[timestamp.iso8601].try(:[], "net_usage_rate_average").should_not eq nil
        stats_counter += 1
      end

      # check total number of 20s blocks
      stats_counter.should eq 150
    end

    it "makes sure start time and end time of collection period are correct" do
      # get start time and end time of the whole 20s stream
      # @write_bytes first doesn't have pair sample in @read_bytes, so first sample is on index 1
      stats_period_start = [api_time_as_utc(@read_bytes.first), api_time_as_utc(@write_bytes.first)].min
      stats_period_end = [api_time_as_utc(@read_bytes.last), api_time_as_utc(@write_bytes.last)].min

      # check start and end date are as expected
      expected_stats_period_start = parse_datetime(NET_LAST_VALUE_OF_FIRST_COLLECTING_PERIOD_TIMESTAMP)
      expected_stats_period_end = parse_datetime('2013-08-28 12:41:40Z')
      stats_period_start.should eq expected_stats_period_start
      stats_period_end.should eq expected_stats_period_end
    end
  end

  #####################################################################################################################
  # These constants are used in both 1. collection period and 2.collection period. These constants should make sure of
  # correct connection of these two periods of mem_usage_absolute_average
  MEM_LAST_VALUE_OF_FIRST_COLLECTING_PERIOD = 19.53125

  context "1. collection period from 2 collection periods total of the mem_usage_absolute_average, end of this "\
          "period has incomplete stat" do
    before do
      @ems_openstack.stub(:get_statistics) do |name, _options|
        first_collection_period = filter_statistics(@mock_stats_data.get_statistics(name,
                                                                                    "multiple_collection_periods"),
                                                    '<=',
                                                    NET_SECOND_COLLECTION_PERIOD_START)

        OpenstackApiResult.new(first_collection_period)
      end

      preload_data
    end

    def preload_data
      @counter_info = Metric::Capture::OpenstackInfra::COUNTER_INFO.find do |c|
        c[:vim_style_counter_key] == "mem_usage_absolute_average"
      end

      # grab read bytes and write bytes data, these values are pulled directly from
      # spec/tools/openstack_data/openstack_perf_data/multiple_collection_periods.yml
      @memory_used =  filter_statistics(@mock_stats_data.get_statistics("hardware.memory.used",
                                                                        "multiple_collection_periods"),
                                        '<=',
                                        NET_SECOND_COLLECTION_PERIOD_START)

      @memory_total = filter_statistics(@mock_stats_data.get_statistics("hardware.memory.total",
                                                                        "multiple_collection_periods"),
                                        '<=',
                                        NET_SECOND_COLLECTION_PERIOD_START)

      _, values_by_id_and_ts = @host.perf_collect_metrics_openstack("perf_capture_data_openstack_infra", "realtime")
      @values_by_ts = values_by_id_and_ts[@host.ems_ref]
      @ts_keys = @values_by_ts.keys.sort
    end

    ###################################################################################################################
    # Complete scenario is the same as net_usage_average
    it "computes first 4 values of mem_usage_absolute_average values correctly" do
      # Make the computations of the stats
      avg_stat1_manual = (
        100.0 / 4096.0 * 3000.0
      )
      avg_stat4_manual = (
        100.0 / 4096.0 * 1300
      )

      avg_stat1_computed_elsewhere = 73.2421875
      avg_stat1 = make_memory_util_calculation(@counter_info, @memory_used, @memory_total, 1)
      avg_stat2_computed_elsewhere = 48.828125
      avg_stat2 = make_memory_util_calculation(@counter_info, @memory_used, @memory_total, 2)
      avg_stat3_computed_elsewhere = 56.15234375
      avg_stat3 = make_memory_util_calculation(@counter_info, @memory_used, @memory_total, 3)
      avg_stat4_computed_elsewhere = 31.73828125
      avg_stat4 = make_memory_util_calculation(@counter_info, @memory_used, @memory_total, 4)

      # ensure computations are equal
      avg_stat1_manual.should eq avg_stat1_computed_elsewhere
      avg_stat4_manual.should eq avg_stat4_computed_elsewhere
      avg_stat1.should eq avg_stat1_computed_elsewhere
      avg_stat2.should eq avg_stat2_computed_elsewhere
      avg_stat3.should eq avg_stat3_computed_elsewhere
      avg_stat4.should eq avg_stat4_computed_elsewhere
    end

    it "checks that the mem_usage_absolute_average has aligned data and computed stats correctly" do
      # make computation of stats for comparison
      avg_stat1 = make_memory_util_calculation(@counter_info, @memory_used, @memory_total, 1)
      avg_stat2 = make_memory_util_calculation(@counter_info, @memory_used, @memory_total, 2)
      avg_stat3 = make_memory_util_calculation(@counter_info, @memory_used, @memory_total, 3)
      avg_stat4 = make_memory_util_calculation(@counter_info, @memory_used, @memory_total, 4)
      avg_stat5 = make_memory_util_calculation(@counter_info, @memory_used, @memory_total, 5)

      # ensure that the first 30 statistics match avg_stat1
      (0..29).each { |i| @values_by_ts[@ts_keys[i]]["mem_usage_absolute_average"].should eq avg_stat1 }
      # ensure that the next 30 statistics match avg_stat2
      (30..59).each { |i| @values_by_ts[@ts_keys[i]]["mem_usage_absolute_average"].should eq avg_stat2 }
      # ensure that the next 30 statistics match avg_stat3
      (60..89).each { |i| @values_by_ts[@ts_keys[i]]["mem_usage_absolute_average"].should eq avg_stat3 }
      # ensure that the next 31 statistics match avg_stat4
      (90..120).each { |i| @values_by_ts[@ts_keys[i]]["mem_usage_absolute_average"].should eq avg_stat4 }
      # ensure that the next 30 statistics match avg_stat5
      (121..150).each { |i| @values_by_ts[@ts_keys[i]]["mem_usage_absolute_average"].should eq avg_stat5 }
    end

    it "checks that the mem_usage_absolute_average should have last incomplete stat not saved" do
      # Ensure that the last 30 statistics match nil. This happens because net usage stat has been incomplete, so we s
      # tore nil values, these nil values should be rewritten in next collection period.
      (151..180).each { |i| @values_by_ts[@ts_keys[i]]["mem_usage_absolute_average"].should eq nil }
    end

    it "checks this collection period has right count of samples saved" do
      # ensure total number of stats is correct, 151 data stats and 30 nil stats
      @ts_keys.count.should eq 181
    end

    it "tests that last computed statistic has the right value" do
      avg_stat5 = make_memory_util_calculation(@counter_info, @memory_used, @memory_total, 5)

      # Test that last value of 1. collection period is this. This test continues in 2. collection period test. This
      # value has to be different to first value of 2.collection period
      avg_stat5.should eq MEM_LAST_VALUE_OF_FIRST_COLLECTING_PERIOD
    end

    it "make sure disk_usage_rate_average stats continuos block of 20s is correct" do
      # get start and end date as expected
      expected_stats_period_start = parse_datetime('2013-08-28 11:01:20')
      expected_stats_period_end = parse_datetime(NET_LAST_VALUE_OF_FIRST_COLLECTING_PERIOD_TIMESTAMP)

      # check that 20s block is not interrupted between start and end time, and that count of 20s block is correct
      stats_counter = 0
      (expected_stats_period_start + 20.seconds..expected_stats_period_end).step_value(20.seconds).each do |timestamp|
        @values_by_ts[timestamp.iso8601].try(:[], "mem_usage_absolute_average").should_not eq nil
        stats_counter += 1
      end

      # check total number of 20s blocks
      stats_counter.should eq 151
    end

    it "makes sure start time and end time of collection period are correct" do
      # get start time and end time of the whole 20s stream
      stats_period_start = [api_time_as_utc(@memory_used.first), api_time_as_utc(@memory_total.first)].min
      # @memory_used last doesn't have pair sample in write bytes, so last sample is on index -2
      stats_period_end = [api_time_as_utc(@memory_used[-2]), api_time_as_utc(@memory_total.last)].min

      # check start and end date are as expected
      expected_stats_period_start = parse_datetime('2013-08-28 11:01:20')
      expected_stats_period_end = parse_datetime(NET_LAST_VALUE_OF_FIRST_COLLECTING_PERIOD_TIMESTAMP)
      stats_period_start.should eq expected_stats_period_start
      stats_period_end.should eq expected_stats_period_end
    end
  end

  context "2. collection period from 2 collection periods total of the mem_usage_absolute_average, start and "\
          "middle of this period has one incomplete stat" do
    before do
      @ems_openstack.stub(:get_statistics) do |name, _options|
        second_collection_period = filter_statistics(@mock_stats_data.get_statistics(name,
                                                                                     "multiple_collection_periods"),
                                                     '>',
                                                     NET_SECOND_COLLECTION_PERIOD_START,
                                                     NET_COLLECTION_OVERLAP_PERIOD)

        OpenstackApiResult.new(second_collection_period)
      end

      @orig_log = $log
      $log = double.as_null_object

      preload_data
    end

    after do
      $log = @orig_log
    end

    def preload_data
      @counter_info = Metric::Capture::OpenstackInfra::COUNTER_INFO.find do |c|
        c[:vim_style_counter_key] == "mem_usage_absolute_average"
      end

      # grab read bytes and write bytes data, these values are pulled directly from
      # spec/tools/openstack_data/openstack_perf_data/multiple_collection_periods.yml
      @memory_used =  filter_statistics(@mock_stats_data.get_statistics("hardware.memory.used",
                                                                        "multiple_collection_periods"),
                                        '>',
                                        NET_SECOND_COLLECTION_PERIOD_START,
                                        NET_COLLECTION_OVERLAP_PERIOD)

      @memory_total = filter_statistics(@mock_stats_data.get_statistics("hardware.memory.total",
                                                                        "multiple_collection_periods"),
                                        '>',
                                        NET_SECOND_COLLECTION_PERIOD_START,
                                        NET_COLLECTION_OVERLAP_PERIOD)
      # Drop fist element of write bytes, as that is an incomplete stat
      @memory_total.shift
      # Drop pre last element of write bytes cause it doesn't have pair sample, therefore it is an incomplete stat
      @memory_total.delete_at(-2)

      _, values_by_id_and_ts = @host.perf_collect_metrics_openstack("perf_capture_data_openstack_infra", "realtime")
      @values_by_ts = values_by_id_and_ts[@host.ems_ref]
      @ts_keys = @values_by_ts.keys.sort
    end

    ###################################################################################################################
    # Complete scenario is the same as net_usage_average

    it "checks that the mem_usage_absolute_average has aligned data and computed stats correctly" do
      # make computation of stats for comparison
      avg_stat1 = make_memory_util_calculation(@counter_info, @memory_used, @memory_total, 1)
      avg_stat2 = make_memory_util_calculation(@counter_info, @memory_used, @memory_total, 2)
      avg_stat3 = make_memory_util_calculation(@counter_info, @memory_used, @memory_total, 3)
      avg_stat4 = make_memory_util_calculation(@counter_info, @memory_used, @memory_total, 4)

      # ensure that the next 30 statistics match avg_stat1
      (21..50).each { |i| @values_by_ts[@ts_keys[i]]["mem_usage_absolute_average"].should eq avg_stat1 }
      # ensure that the next 30 statistics match avg_stat2
      (51..80).each { |i| @values_by_ts[@ts_keys[i]]["mem_usage_absolute_average"].should eq avg_stat2 }
      # ensure that the next 30 statistics match avg_stat3
      (81..110).each { |i| @values_by_ts[@ts_keys[i]]["mem_usage_absolute_average"].should eq avg_stat3 }
      # ensure that the next 60 statistics match avg_stat4
      # This test assures us that this value fills the empty space caused by corrupted data with missing stat.
      (111..170).each { |i| @values_by_ts[@ts_keys[i]]["mem_usage_absolute_average"].should eq avg_stat4 }
    end

    it "checks that the mem_usage_absolute_average should have last incomplete stat not saved" do
      # Ensure that the first 21 statistics match nil. This happens because there is one more stat of
      # hardware.system_stats.cpu.util, but net usage stat has been incomplete, so we store nil values, those nil
      # values has been filled with the right value in previous collection period.
      # !!!!!!! It's up to saving mechanism to not overwrite the old values with nil. !!!!!!!!!!!
      (0..20).each { |i| @values_by_ts[@ts_keys[i]]["mem_usage_absolute_average"].should eq nil }
    end

    it "checks this collection period has right count of samples saved" do
      # ensure total number of stats is correct, 150 data stats and 21 nil stats
      @ts_keys.count.should eq 171
    end

    it "checks that last sample of 1. collection period is different to first sample of 2. collection period" do
      # make computation of stats for comparison
      avg_stat1 = make_memory_util_calculation(@counter_info, @memory_used, @memory_total, 1)

      avg_stat1.should_not eq MEM_LAST_VALUE_OF_FIRST_COLLECTING_PERIOD
    end

    it "there is missing stat in the middle of the period, make sure we log warning of corrupted data exactly once" do
      # should fail twice for mem_usage and net_usage
      $log.should_receive(:warn).with(/Distance of the multiple streams of data is invalid/).exactly(:twice)
      @host.perf_collect_metrics_openstack("perf_capture_data_openstack_infra", "realtime")
    end

    it "make sure disk_usage_rate_average stats continuos block of 20s is correct" do
      expected_stats_period_start = parse_datetime(NET_LAST_VALUE_OF_FIRST_COLLECTING_PERIOD_TIMESTAMP)
      expected_stats_period_end = parse_datetime('2013-08-28 12:41:40Z')

      # check that 20s block is not interrupted between start and end time, and that count of 20s block is correct
      stats_counter = 0
      (expected_stats_period_start + 20.seconds..expected_stats_period_end).step_value(20.seconds).each do |timestamp|
        @values_by_ts[timestamp.iso8601].try(:[], "mem_usage_absolute_average").should_not eq nil
        stats_counter += 1
      end

      # check total number of 20s blocks
      stats_counter.should eq 150
    end

    it "makes sure start time and end time of collection period are correct" do
      # get start time and end time of the whole 20s stream
      # @memory_total first doesn't have pair sample in @memory_used, so first sample is on index 1
      stats_period_start = [api_time_as_utc(@memory_used.first), api_time_as_utc(@memory_total.first)].min
      stats_period_end = [api_time_as_utc(@memory_used.last), api_time_as_utc(@memory_total.last)].min

      # check start and end date are as expected
      expected_stats_period_start = parse_datetime(NET_LAST_VALUE_OF_FIRST_COLLECTING_PERIOD_TIMESTAMP)
      expected_stats_period_end = parse_datetime('2013-08-28 12:41:40Z')
      stats_period_start.should eq expected_stats_period_start
      stats_period_end.should eq expected_stats_period_end
    end
  end

  def filter_statistics(stats, op, date, subtract_by = nil)
    filter_date  = parse_datetime(date)
    filter_date -= subtract_by if subtract_by
    stats.select { |x| x['period_end'].send(op, filter_date) }
  end

  def make_memory_util_calculation(counter_info, memory_used, memory_total, index)
    counter_info[:calculation].call(
      {
        "hardware.memory.used"  => memory_used[index]['avg'],
        "hardware.memory.total" => memory_total[index]['avg'],
      }, nil)
  end

  def make_calculation(counter_info, counter_one, counter_two, write_stats, read_stats, first_index, second_index)
    counter_info[:calculation].call(
      {
        counter_one => write_stats[second_index]['avg'] - write_stats[first_index]['avg'],
        counter_two => read_stats[second_index]['avg'] - read_stats[first_index]['avg']
      },
      counter_one => (api_duration_time_as_utc(write_stats[second_index]) -
          api_duration_time_as_utc(write_stats[first_index])),
      counter_two => (api_duration_time_as_utc(read_stats[second_index]) -
          api_duration_time_as_utc(read_stats[first_index]))
      )
  end

  def api_time_as_utc(api_result)
    period_end = api_result["period_end"]
    parse_datetime(period_end)
  end

  def api_duration_time_as_utc(api_result)
    duration_end = api_result["duration_end"]
    parse_datetime(duration_end)
  end

  def parse_datetime(datetime)
    datetime << "Z" if datetime.size == 19
    Time.parse(datetime)
  end
end
