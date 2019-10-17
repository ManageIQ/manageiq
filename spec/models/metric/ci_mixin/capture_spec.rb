describe Metric::CiMixin::Capture do
  require ManageIQ::Providers::Openstack::Engine.root.join("spec/tools/openstack_data/openstack_data_test_helper")
  let(:zone) { EvmSpecHelper.create_guid_miq_server_zone[2] }
  let(:mock_meter_list) { OpenstackMeterListData.new }
  let(:mock_stats_data) { OpenstackMetricStatsData.new }
  let(:metering) do
    double(:metering,
           :list_meters => OpenstackApiResult.new((mock_meter_list.list_meters("resource_counters") +
                              mock_meter_list.list_meters("metadata_counters"))))
  end
  let(:ems_openstack) { FactoryBot.create(:ems_openstack, :zone => zone) }
  let(:vm) { FactoryBot.create(:vm_perf_openstack, :ext_management_system => ems_openstack) }

  before do
    allow(ems_openstack).to receive(:connect).with(:service => "Metering").and_return(metering)
  end

  describe "#perf_capture_realtime integration tests" do
    let(:expected_stats_period_start) { parse_datetime('2013-08-28T11:01:20Z') }
    let(:expected_stats_period_end) { parse_datetime('2013-08-28T12:41:40Z') }
    let(:expected_timestamps) { (expected_stats_period_start + 20.seconds..expected_stats_period_end).step_value(20.seconds) }

    def capture_data(second_collection_period_start, collection_overlap_period)
      # 1.collection period, save all metrics
      allow(metering).to receive(:get_statistics) do |name, _options|
        first_collection_period = filter_statistics(mock_stats_data.get_statistics(name, "multiple_collection_periods"),
                                                    '<=',
                                                    second_collection_period_start)

        OpenstackApiResult.new(first_collection_period)
      end

      allow(vm).to receive(:state_changed_on).and_return(second_collection_period_start)
      vm.perf_capture_realtime(Time.parse('2013-08-28T11:01:40Z').utc, Time.parse(second_collection_period_start).utc)

      # 2.collection period, save all metrics
      allow(metering).to receive(:get_statistics) do |name, _options|
        second_collection_period = filter_statistics(mock_stats_data.get_statistics(name, "multiple_collection_periods"),
                                                     '>',
                                                     second_collection_period_start,
                                                     collection_overlap_period)

        OpenstackApiResult.new(second_collection_period)
      end

      allow(vm).to receive(:state_changed_on).and_return(second_collection_period_start)
      vm.perf_capture_realtime(Time.parse(second_collection_period_start).utc, Time.parse('2013-08-28T14:02:00Z').utc)

      @metrics_by_ts = {}
      vm.metrics.reload.each do |x|
        @metrics_by_ts[x.timestamp.iso8601] = x
      end

      # grab read bytes and write bytes data, these values are pulled directly from
      # spec/tools/openstack_data/openstack_perf_data/multiple_collection_periods.yml
      @read_bytes = mock_stats_data.get_statistics("network.incoming.bytes",
                                                   "multiple_collection_periods")

      @write_bytes = mock_stats_data.get_statistics("network.outgoing.bytes",
                                                    "multiple_collection_periods")
    end

    def filter_statistics(stats, op, date, subtract_by = nil)
      filter_date = parse_datetime(date)
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

    def mock_adapter(postgre_adapter)
      connection_config = {:adapter => postgre_adapter, :database => "manageiq_metrics"}
      adapter           = "#{postgre_adapter}_adapter"
      # require "active_metrics/connection_adapters/#{adapter}"
      adapter_class  = ActiveMetrics::ConnectionAdapters.const_get(adapter.classify)
      raw_connection = adapter_class.create_connection(connection_config)

      allow(ActiveMetrics::Base).to receive(:connection).and_return(adapter_class.new(raw_connection))
      allow(ActiveMetrics::Base).to receive(:connection_config).and_return(connection_config)
    end

    ["miq_postgres", "miq_postgres_legacy"].each do |postgre_adapter|
      context "with adapter #{postgre_adapter}" do
        before do
          mock_adapter(postgre_adapter)
        end

        context "2 collection periods total, end of 1. period has complete stats" do
          it "checks that saved metrics are correct" do
            capture_data('2013-08-28T12:06:00Z', 20.minutes)

            stats_period_start = [api_time_as_utc(@read_bytes.first), api_time_as_utc(@write_bytes.first)].min
            stats_period_end   = [api_time_as_utc(@read_bytes.last), api_time_as_utc(@write_bytes.last)].min

            # check start date and end date
            expect(stats_period_start).to eq expected_stats_period_start
            expect(stats_period_end).to eq expected_stats_period_end

            # check that 20s block is not interrupted between start and end time for net_usage_rate_average
            expected_timestamps.each do |timestamp|
              expect(@metrics_by_ts[timestamp.iso8601].try(:net_usage_rate_average)).not_to eq nil
            end

            # check that 20s block is not interrupted between start and end time for disk_usage_rate_average
            expected_timestamps.each do |timestamp|
              expect(@metrics_by_ts[timestamp.iso8601].try(:disk_usage_rate_average)).not_to eq nil
            end

            # check that 20s block is not interrupted between start and end time for cpu_usage_rate_average
            expected_timestamps.each do |timestamp|
              expect(@metrics_by_ts[timestamp.iso8601].try(:cpu_usage_rate_average)).not_to eq nil
            end
          end
        end

        context "2 collection periods total, there is data hole between periods" do
          it "verifies that hole in the data is logged, corrupted data is logged and no other warnings are logged" do
            # Hole in the data is logged
            expect($log).to receive(:warn).with(/expected to get data as of/).exactly(:once)
            # Corrupted data is logged NOTE: This is emitted from the provider
            expect($log).to receive(:warn).with(/Distance of the multiple streams of data is invalid/).exactly(:once)
            # No to other warnings should be logged
            expect($log).not_to receive(:warn)

            # sending no collection period overlap will cause hole in the data
            capture_data('2013-08-28T11:56:00Z', nil)
          end
        end

        context "2 collection periods total, end of 1. period has incomplete stat" do
          it "checks that saved metrics are correct" do
            capture_data('2013-08-28T12:02:00Z', 20.minutes)

            stats_period_start = [api_time_as_utc(@read_bytes.first), api_time_as_utc(@write_bytes.first)].min
            stats_period_end   = [api_time_as_utc(@read_bytes.last), api_time_as_utc(@write_bytes.last)].min

            # check start date and end date
            expect(stats_period_start).to eq expected_stats_period_start
            expect(stats_period_end).to eq expected_stats_period_end

            # check that 20s block is not interrupted between start and end time for net_usage_rate_average
            expected_timestamps.each do |timestamp|
              expect(@metrics_by_ts[timestamp.iso8601].try(:net_usage_rate_average)).not_to eq nil
            end

            # check that 20s block is not interrupted between start and end time for disk_usage_rate_average
            expected_timestamps.each do |timestamp|
              expect(@metrics_by_ts[timestamp.iso8601].try(:disk_usage_rate_average)).not_to eq nil
            end

            # check that 20s block is not interrupted between start and end time for cpu_usage_rate_average
            expected_timestamps.each do |timestamp|
              expect(@metrics_by_ts[timestamp.iso8601].try(:cpu_usage_rate_average)).not_to eq nil
            end
          end
        end
      end
    end

    context "comparing miq_postgres and miq_postgres_legacy adapters" do
      it "creates the same metrics in the DB, starting with empty db" do
        # Do a capture data with new_adapter
        mock_adapter("miq_postgres_legacy")
        expect(ActiveMetrics::Base.connection.class).to eq(ActiveMetrics::ConnectionAdapters::MiqPostgresLegacyAdapter)
        capture_data('2013-08-28T12:02:00Z', 20.minutes)

        legacy_adapter_stored_data = @metrics_by_ts

        # Delete the metrics so we can fetch them again with new adapter
        Metric.delete_all

        # Do a capture data with new_adapter
        mock_adapter("miq_postgres")
        expect(ActiveMetrics::Base.connection.class).to eq(ActiveMetrics::ConnectionAdapters::MiqPostgresAdapter)
        capture_data('2013-08-28T12:02:00Z', 20.minutes)

        new_adapter_stored_data = @metrics_by_ts

        # Assert the number of saved metrics is the same
        expect(new_adapter_stored_data.keys.count).to be > 0
        expect(new_adapter_stored_data.keys.count).to eq(legacy_adapter_stored_data.keys.count)

        # Assert that the metrics are exactly the same
        legacy_adapter_stored_data.each do |timestamp, data|
          legacy_adapter_attributes = data.attributes.except("id", "created_on")
          new_adapter_attributes    = new_adapter_stored_data[timestamp].attributes.except("id", "created_on")
          # Is there an hash exact match matcher? Include from both sides does exact match, but it's a bit clunky
          expect(legacy_adapter_attributes).to include(new_adapter_attributes)
          expect(new_adapter_attributes).to include(legacy_adapter_attributes)
        end

        # Assert the created on of new metrics is bigger, to make sure we did change the data
        legacy_adapter_stored_data.each do |timestamp, data|
          expect(data.created_on).to be < new_adapter_stored_data[timestamp].created_on
        end
      end

      it "doesn't change the data when changing from legacy_driver to new_driver" do
        # Do a capture data with new_adapter
        mock_adapter("miq_postgres")
        expect(ActiveMetrics::Base.connection.class).to eq(ActiveMetrics::ConnectionAdapters::MiqPostgresAdapter)
        capture_data('2013-08-28T12:02:00Z', 20.minutes)

        new_adapter_stored_data = @metrics_by_ts

        # Do a capture data with new_adapter
        mock_adapter("miq_postgres_legacy")
        expect(ActiveMetrics::Base.connection.class).to eq(ActiveMetrics::ConnectionAdapters::MiqPostgresLegacyAdapter)
        capture_data('2013-08-28T12:02:00Z', 20.minutes)

        legacy_adapter_stored_data = @metrics_by_ts

        # Assert the number of saved metrics is the same
        expect(new_adapter_stored_data.keys.count).to be > 0
        expect(new_adapter_stored_data.keys.count).to eq(legacy_adapter_stored_data.keys.count)

        # Assert that the metrics are exactly the same
        legacy_adapter_stored_data.each do |timestamp, data|
          legacy_adapter_attributes = data.attributes
          new_adapter_attributes    = new_adapter_stored_data[timestamp].attributes
          # Is there an hash exact match matcher? Include from both sides does exact match, but it's a bit clunky
          expect(legacy_adapter_attributes).to include(new_adapter_attributes)
          expect(new_adapter_attributes).to include(legacy_adapter_attributes)
        end
      end

      it "doesn't change the data when changing from new_driver to legacy_driver" do
        # Do a capture data with new_adapter
        mock_adapter("miq_postgres_legacy")
        expect(ActiveMetrics::Base.connection.class).to eq(ActiveMetrics::ConnectionAdapters::MiqPostgresLegacyAdapter)
        capture_data('2013-08-28T12:02:00Z', 20.minutes)

        legacy_adapter_stored_data = @metrics_by_ts

        # Do a capture data with new_adapter
        mock_adapter("miq_postgres")
        expect(ActiveMetrics::Base.connection.class).to eq(ActiveMetrics::ConnectionAdapters::MiqPostgresAdapter)
        capture_data('2013-08-28T12:02:00Z', 20.minutes)

        new_adapter_stored_data = @metrics_by_ts

        # Assert the number of saved metrics is the same
        expect(new_adapter_stored_data.keys.count).to be > 0
        expect(new_adapter_stored_data.keys.count).to eq(legacy_adapter_stored_data.keys.count)

        # Assert that the metrics are exactly the same
        legacy_adapter_stored_data.each do |timestamp, data|
          legacy_adapter_attributes = data.attributes
          new_adapter_attributes    = new_adapter_stored_data[timestamp].attributes
          # Is there an hash exact match matcher? Include from both sides does exact match, but it's a bit clunky
          expect(legacy_adapter_attributes).to include(new_adapter_attributes)
          expect(new_adapter_attributes).to include(legacy_adapter_attributes)
        end
      end
    end
  end

  describe "#perf_capture_queue('realtime')" do
    def verify_realtime_queue_item(queue_item, expected_start_time = nil)
      expect(queue_item.method_name).to eq "perf_capture_realtime"
      if expected_start_time
        q_start_time = queue_item.args.first
        expect(q_start_time).to be_within(0.00001).of expected_start_time
      end
    end

    def verify_historical_queue_item(queue_item, expected_start_time, expected_end_time)
      expect(queue_item.method_name).to eq "perf_capture_historical"
      q_start_time, q_end_time = queue_item.args
      expect(q_start_time).to be_within(0.00001).of expected_start_time
      expect(q_end_time).to be_within(0.00001).of expected_end_time
    end

    def verify_perf_capture_queue(last_perf_capture_on, total_queue_items)
      Timecop.freeze do
        vm.last_perf_capture_on = last_perf_capture_on
        vm.perf_capture_queue("realtime")
        expect(MiqQueue.count).to eq total_queue_items

        # make sure the queue items are in the correct order
        queue_items = MiqQueue.order(:id).to_a

        # first queue item is realtime and only has a start time
        realtime_cut_off = 4.hours.ago.utc.beginning_of_day
        realtime_start_time = realtime_cut_off if last_perf_capture_on.nil? || last_perf_capture_on < realtime_cut_off
        verify_realtime_queue_item(queue_items.shift, realtime_start_time)

        # rest of the queue items should be historical
        if queue_items.any? && realtime_start_time
          interval_start_time = vm.last_perf_capture_on
          interval_end_time   = interval_start_time + 1.day
          queue_items.reverse_each do |q_item|
            verify_historical_queue_item(q_item, interval_start_time, interval_end_time)

            interval_start_time = interval_end_time
            interval_end_time  += 1.day # if collection threshold is parameterized, this increment should change
            interval_end_time   = realtime_start_time if interval_end_time > realtime_start_time
          end
        end
      end
    end

    it "when last_perf_capture_on is nil (first time)" do
      MiqQueue.delete_all
      Timecop.freeze do
        Timecop.travel(Time.now.end_of_day - 6.hours)
        verify_perf_capture_queue(nil, 1)
        Timecop.travel(Time.now + 20.minutes)
        verify_perf_capture_queue(nil, 1)
      end
    end

    it "when last_perf_capture_on is very old (older than the realtime_cut_off of 4.hours.ago)" do
      MiqQueue.delete_all
      Timecop.freeze do
        Timecop.travel(Time.now.end_of_day - 6.hours)
        verify_perf_capture_queue((10.days + 5.hours + 23.minutes).ago, 11)
      end
    end

    it "when last_perf_capture_on is recent (before the realtime_cut_off of 4.hours.ago)" do
      MiqQueue.delete_all
      Timecop.freeze do
        Timecop.travel(Time.now.end_of_day - 6.hours)
        verify_perf_capture_queue((0.days + 2.hours + 5.minutes).ago, 1)
      end
    end

    it "is able to handle multiple attempts to queue perf_captures and not add new items" do
      MiqQueue.delete_all
      Timecop.freeze do
        # set a specific time of day to avoid sporadic test failures that fall on the exact right time to bump the
        # queue items to 12 instead of 11
        current_time = Time.now.end_of_day - 6.hours
        Timecop.travel(current_time)
        last_perf_capture_on = (10.days + 5.hours + 23.minutes).ago
        verify_perf_capture_queue(last_perf_capture_on, 11)
        Timecop.travel(current_time + 20.minutes)
        verify_perf_capture_queue(last_perf_capture_on, 11)
      end
    end

    it "links supplied miq_task with queued item which allow to initialize MiqTask#started_on attribute" do
      MiqQueue.delete_all
      task = FactoryBot.create(:miq_task)
      vm.perf_capture_queue("realtime", :task_id => task.id)
      expect(MiqQueue.first.miq_task_id).to eq task.id
    end
  end

  describe "#perf_capture_queue('historical')" do
    context "with capture days > 0 and multiple attempts" do
      def verify_perf_capture_queue_historical(last_perf_capture_on, total_queue_items)
        vm.last_perf_capture_on = last_perf_capture_on
        vm.perf_capture_queue("historical")
        expect(MiqQueue.count).to eq total_queue_items
      end

      it "when last_perf_capture_on is nil(first time)" do
        MiqQueue.delete_all
        Timecop.freeze do
          allow(Metric::Capture).to receive(:historical_days).and_return(7)
          current_time = Time.now.end_of_day - 6.hours
          Timecop.travel(current_time)
          verify_perf_capture_queue_historical(nil, 8)
          Timecop.travel(current_time + 20.minutes)
          verify_perf_capture_queue_historical(nil, 8)
        end
      end

      it "when last_perf_capture_on is very old" do
        MiqQueue.delete_all
        Timecop.freeze do
          # set a specific time of day to avoid sporadic test failures that fall on the exact right time to bump the
          # queue items to 12 instead of 11
          allow(Metric::Capture).to receive(:historical_days).and_return(7)
          current_time = Time.now.end_of_day - 6.hours
          last_capture_on = (10.days + 5.hours + 23.minutes).ago
          Timecop.travel(current_time)
          verify_perf_capture_queue_historical(last_capture_on, 8)
          Timecop.travel(current_time + 20.minutes)
          verify_perf_capture_queue_historical(last_capture_on, 8)
        end
      end

      it "when last_perf_capture_on is fairly recent" do
        MiqQueue.delete_all
        Timecop.freeze do
          # set a specific time of day to avoid sporadic test failures that fall on the exact right time to bump the
          # queue items to 12 instead of 11
          allow(Metric::Capture).to receive(:historical_days).and_return(7)
          current_time = Time.now.end_of_day - 6.hours
          last_capture_on = (10.days + 5.hours + 23.minutes).ago
          Timecop.travel(current_time)
          verify_perf_capture_queue_historical(last_capture_on, 8)
          Timecop.travel(current_time + 20.minutes)
          verify_perf_capture_queue_historical(last_capture_on, 8)
        end
      end
    end
  end

  context "handles archived container entities" do
    it "get the correct queue name and zone from archived container entities" do
      ems = FactoryBot.create(:ems_openshift, :name => 'OpenShiftProvider')
      group = FactoryBot.create(:container_group, :name => "group", :ext_management_system => ems)
      container = FactoryBot.create(:container,
                                     :name                  => "container",
                                     :container_group       => group,
                                     :ext_management_system => ems)
      project = FactoryBot.create(:container_project,
                                   :name                  => "project",
                                   :ext_management_system => ems)
      container.disconnect_inv
      group.disconnect_inv
      project.disconnect_inv

      expect(container.ems_for_capture_target).to eq ems
      expect(group.ems_for_capture_target).to     eq ems
      expect(project.ems_for_capture_target).to   eq ems

      expect(container.my_zone).to eq ems.my_zone
      expect(group.my_zone).to eq ems.my_zone
      expect(project.my_zone).to eq ems.my_zone
    end
  end
end
