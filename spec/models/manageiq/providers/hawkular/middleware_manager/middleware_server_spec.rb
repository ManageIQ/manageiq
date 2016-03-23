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
                       :feed                  => '9d9dc5f7-40aa-458a-beb2-aebfc55092bc',
                       :nativeid              => 'Local~~',
                       :ext_management_system => ems_hawkular)
  end

  it "#collect_live_metrics for all metrics available" do
    end_time = Time.new(2016, 3, 18, 0, 0, 0, "+01:00")      # Fixed time for testing
    start_time = Time.new(2016, 3, 17, 0, 0, 0, "+01:00")    # Fixed time for testing
    interval = 20                                            # Interval in seconds
    VCR.use_cassette(described_class.name.underscore.to_s,
                     :allow_unused_http_interactions => true) do # , :record => :new_episodes) do
      metrics_available = eap.metrics_available
      metrics_data = eap.collect_live_metrics(metrics_available, start_time, end_time, interval)
      keys = metrics_data.keys
      expect(metrics_data[keys[0]].keys.size).to be > 3
    end
  end

  it "#collect_live_metrics for three metrics" do
    end_time = Time.new(2016, 3, 18, 0, 0, 0, "+01:00")      # Fixed time for testing
    start_time = Time.new(2016, 3, 17, 0, 0, 0, "+01:00")    # Fixed time for testing
    interval = 20                                            # Interval in seconds
    VCR.use_cassette(described_class.name.underscore.to_s,
                     :allow_unused_http_interactions => true) do # , :record => :new_episodes) do
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
                     :allow_unused_http_interactions => true) do # , :record => :new_episodes) do
      capture = eap.first_and_last_capture
      expect(capture[0]).to be < capture[1]
    end
  end
end
