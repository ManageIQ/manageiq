describe ManageIQ::Providers::Hawkular::MiddlewareManager::EventCatcher::Stream do
  subject do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    auth                 = AuthToken.new(:name     => "test",
                                         :auth_key => "valid-token",
                                         :userid   => "jdoe",
                                         :password => "password")
    ems                  = FactoryGirl.create(:ems_hawkular,
                                              :hostname        => 'localhost',
                                              :port            => 8080,
                                              :authentications => [auth],
                                              :zone            => zone)
    described_class.new(ems)
  end

  context "#each_batch" do
    # VCR.eject_cassette
    # VCR.turn_off!(ignore_cassettes: true)

    VCR.configure do |c|
      c.default_cassette_options = {
        :match_requests_on => [:method, VCR.request_matchers.uri_without_params(:startTime)]
      }
    end

    it "yields a valid event" do
      # if generating a cassette the polling window is the previous 1 minute
      VCR.use_cassette(described_class.name.underscore.to_s) do # , :record => :new_episodes) do
        result = []
        subject.start
        subject.each_batch do |events|
          result = events
          subject.stop
        end
        expect(result.count).to be == 1
        expect(result[0].category).to eq 'Hawkular Deployment'
      end
    end
  end
end
