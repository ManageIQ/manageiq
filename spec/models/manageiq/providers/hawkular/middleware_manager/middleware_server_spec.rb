describe ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareServer do
  let(:ems_hawkular) do
    # allow(MiqServer).to receive(:my_zone).and_return("default")
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    auth = AuthToken.new(:name => "test", :auth_key => "valid-token", :userid => "jdoe", :password => "password")
    FactoryGirl.create(:ems_hawkular,
                       :hostname        => 'localhost',
                       :port            => 8080,
                       :authentications => [auth],
                       :zone            => zone)
  end

  let(:eap) do
    FactoryGirl.create(:hawkular_middleware_server,
                       :name                  => 'Local',
                       :feed                  => '3790a668-eb4d-47ba-be15-bcf658bb88ba',
                       :ems_ref               => '/t;28026b36-8fe4-4332-84c8-524e173a68bf'\
                                                 '/f;3790a668-eb4d-47ba-be15-bcf658bb88ba/r;Local~~',
                       :nativeid              => 'Local~~',
                       :ext_management_system => ems_hawkular)
  end

  it "#collect_live_metrics for all metrics available" do
    start_time = Time.new(2016, 5, 17, 15, 0, 0, "+02:00")
    end_time = Time.new(2016, 5, 18, 0, 0, 0, "+02:00")
    interval = 3600
    VCR.use_cassette(described_class.name.underscore.to_s,
                     :allow_unused_http_interactions => true,
                     :decode_compressed_response     => true) do # , :record => :new_episodes) do
      metrics_available = eap.metrics_available
      metrics_data = eap.collect_live_metrics(metrics_available, start_time, end_time, interval)
      keys = metrics_data.keys
      expect(metrics_data[keys[0]].keys.size).to be > 3
    end
  end

  it "#collect_live_metrics for three metrics" do
    start_time = Time.new(2016, 5, 17, 15, 0, 0, "+02:00")
    end_time = Time.new(2016, 5, 18, 0, 0, 0, "+02:00")
    interval = 3600
    VCR.use_cassette(described_class.name.underscore.to_s,
                     :allow_unused_http_interactions => true,
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
      expect(capture[0]).to be < capture[1]
    end
  end

  it "#supported_metrics" do
    expected_metrics = {
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
      "Server Availability~App Server"                                    => "mw_availability_app_server"
    }.freeze
    supported_metrics = MiddlewareServer.supported_metrics
    expected_metrics.each { |k, v| expect(supported_metrics[k]).to eq(v) }
  end
end
