describe ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareServer do
  let(:ems_hawkular) do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    auth = AuthToken.new(:name => "test", :auth_key => "valid-token", :userid => "jdoe", :password => "password")
    FactoryGirl.create(:ems_hawkular,
                       :hostname        => 'localhost',
                       :port            => 8080,
                       :authentications => [auth])
  end

  it "will query live metrics for all metrics available" do
    end_time = Time.new(2016, 3, 18, 0, 0, 0, "+01:00")      # Fixed time for testing
    start_time = Time.new(2016, 3, 17, 0, 0, 0, "+01:00")    # Fixed time for testing
    interval = 20                                            # Interval in seconds
    VCR.use_cassette(described_class.name.underscore.to_s) do # , :record => :new_episodes) do
      EmsRefresh.refresh(ems_hawkular)
      ems_hawkular.reload
      expect(ems_hawkular.middleware_servers.size).to be > 0
      ems_hawkular.middleware_servers.each do |eap|
        metrics_data = eap.metrics(start_time, end_time, interval)
        keys = metrics_data.keys
        expect(metrics_data[keys[0]].keys.size).to be > 3
      end
    end
  end

  it "will query live metrics for three metrics available" do
    end_time = Time.new(2016, 3, 18, 0, 0, 0, "+01:00")      # Fixed time for testing
    start_time = Time.new(2016, 3, 17, 0, 0, 0, "+01:00")    # Fixed time for testing
    interval = 20                                            # Interval in seconds
    VCR.use_cassette(described_class.name.underscore.to_s,
                     :allow_unused_http_interactions => true) do # , :record => :new_episodes) do
      EmsRefresh.refresh(ems_hawkular)
      ems_hawkular.reload
      expect(ems_hawkular.middleware_servers.size).to be > 0
      ems_hawkular.middleware_servers.each do |eap|
        metrics_available = eap.metrics_available
        expect(metrics_available.size).to be > 3
        metrics_data = eap.metrics(metrics_available[0],
                                   metrics_available[1],
                                   metrics_available[2],
                                   start_time,
                                   end_time,
                                   interval)
        keys = metrics_data.keys
        # Assuming that for the test the first key has data for 3 metrics
        expect(metrics_data[keys[0]].keys.size).to eq(3)
      end
    end
  end
end
