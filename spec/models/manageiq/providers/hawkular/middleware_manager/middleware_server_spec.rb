require_relative 'hawkular_helper'

# VCR Cassettes: Hawkular Services 0.0.13.Final-SNAPSHOT (commit 3cef2062513f4d949aa21a90db51f9cd105cf329)

describe ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareServer do

  let(:ems_hawkular) do
    # allow(MiqServer).to receive(:my_zone).and_return("default")
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    auth = AuthToken.new(:name     => "test",
                         :auth_key => "valid-token",
                         :userid   => test_userid,
                         :password => test_password)
    FactoryGirl.create(:ems_hawkular,
                       :hostname        => test_hostname,
                       :port            => test_port,
                       :authentications => [auth],
                       :zone            => zone)
  end

  let(:eap) do
    FactoryGirl.create(:hawkular_middleware_server,
                       :name                  => 'Local',
                       :feed                  => the_feed_id,
                       :ems_ref               => '/t;hawkular'\
                                                 "/f;#{the_feed_id}/r;Local~~",
                       :nativeid              => 'Local~~',
                       :ext_management_system => ems_hawkular)
  end

  let(:expected_metrics) do
    {
      "WildFly Memory Metrics~Heap Used"                                  => "mw_heap_used",
      "WildFly Memory Metrics~Heap Max"                                   => "mw_heap_max",
      "WildFly Memory Metrics~Heap Committed"                             => "mw_heap_committed",
      "WildFly Memory Metrics~NonHeap Used"                               => "mw_non_heap_used",
      "WildFly Memory Metrics~NonHeap Committed"                          => "mw_non_heap_committed",
      "WildFly Memory Metrics~Accumulated GC Duration"                    => "mw_accumulated_gc_duration",
      "WildFly Aggregated Web Metrics~Aggregated Servlet Request Time"    => "mw_agregated_servlet_time",
      "WildFly Aggregated Web Metrics~Aggregated Servlet Request Count"   => "mw_aggregated_servlet_request_count",
      "WildFly Aggregated Web Metrics~Aggregated Expired Web Sessions"    => "mw_aggregated_expired_web_sessions",
      "WildFly Aggregated Web Metrics~Aggregated Max Active Web Sessions" => "mw_aggregated_max_active_web_sessions",
      "WildFly Aggregated Web Metrics~Aggregated Active Web Sessions"     => "mw_aggregated_active_web_sessions",
      "WildFly Aggregated Web Metrics~Aggregated Rejected Web Sessions"   => "mw_aggregated_rejected_web_sessions",
      "WildFly Threading Metrics~Thread Count"                            => "mw_thread_count",
      "Server Availability~App Server"                                    => "mw_availability_app_server",
      "Transactions Metrics~Number of Aborted Transactions"               => "mw_tx_aborted",
      "Transactions Metrics~Number of In-Flight Transactions"             => "mw_tx_inflight",
      "Transactions Metrics~Number of Committed Transactions"             => "mw_tx_committed",
      "Transactions Metrics~Number of Transactions"                       => "mw_tx_total",
      "Transactions Metrics~Number of Application Rollbacks"              => "mw_tx_application_rollbacks",
      "Transactions Metrics~Number of Resource Rollbacks"                 => "mw_tx_resource_rollbacks",
      "Transactions Metrics~Number of Timed Out Transactions"             => "mw_tx_timeout",
      "Transactions Metrics~Number of Nested Transactions"                => "mw_tx_nested",
      "Transactions Metrics~Number of Heuristics"                         => "mw_tx_heuristics"
    }.freeze
  end

  it "#collect_stats_metrics" do
    start_time = test_start_time
    end_time = test_end_time
    interval = 3600
    VCR.use_cassette(described_class.name.underscore.to_s,
                     :allow_unused_http_interactions => true,
                     :match_requests_on              => [:method, :uri, :body],
                     :decode_compressed_response     => true) do # , :record => :new_episodes) do
      metrics_available = eap.metrics_available
      metrics_ids_map, raw_stats = eap.collect_stats_metrics(metrics_available, start_time, end_time, interval)
      expect(metrics_ids_map.keys.size).to be > 0
      expect(raw_stats.keys.size).to be > 0
    end
  end

  it "#collect_live_metrics for all metrics available" do
    start_time = test_start_time
    end_time = test_end_time
    interval = 3600
    VCR.use_cassette(described_class.name.underscore.to_s,
                     :allow_unused_http_interactions => true,
                     :match_requests_on              => [:method, :uri, :body],
                     :decode_compressed_response     => true) do # , :record => :new_episodes) do
      metrics_available = eap.metrics_available
      metrics_data = eap.collect_live_metrics(metrics_available, start_time, end_time, interval)
      keys = metrics_data.keys
      expect(metrics_data[keys[0]].keys.size).to be > 3
    end
  end

  it "#collect_live_metrics for three metrics" do
    start_time = test_start_time
    end_time = test_end_time
    interval = 3600
    VCR.use_cassette(described_class.name.underscore.to_s,
                     :allow_unused_http_interactions => true,
                     :match_requests_on              => [:method, :uri, :body],
                     :decode_compressed_response     => true) do # , :record => :new_episodes) do
      metrics_available = eap.metrics_available
      expect(metrics_available.size).to be > 3
      metrics_data = eap.collect_live_metrics(metrics_available[0, 3],
                                              start_time,
                                              end_time,
                                              interval)
      keys = metrics_data.keys
      # Assuming that for the test the first key has data for 3 metrics
      expect(metrics_data[keys[0]].keys.size).to eq(3)
    end
  end

  it "#first_and_last_capture" do
    VCR.use_cassette(described_class.name.underscore.to_s,
                     :allow_unused_http_interactions => true,
                     :decode_compressed_response     => true) do # , :record => :new_episodes) do
      capture = eap.first_and_last_capture
      expect(capture.any?).to be true
      expect(capture[0]).to be < capture[1]
    end
  end

  it "#supported_metrics" do
    supported_metrics = eap.supported_metrics
    expected_metrics.each { |k, v| expect(supported_metrics[k]).to eq(v) }

    _model, model_config = MiddlewareServer.live_metrics_config.first
    supported_metrics = model_config['supported_metrics']
    expected_metrics.each { |k, v| expect(supported_metrics[k]).to eq(v) }
  end

  it "#metrics_available" do
    VCR.use_cassette(described_class.name.underscore.to_s,
                     :allow_unused_http_interactions => true,
                     :decode_compressed_response     => true) do # , :record => :new_episodes) do
      metrics_available = eap.metrics_available
      metrics_available.each { |metric| expect(expected_metrics.value?(metric[:name])).to be(true) }
    end
  end
end
