RSpec.describe Metric::CiMixin::Capture do
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
end
