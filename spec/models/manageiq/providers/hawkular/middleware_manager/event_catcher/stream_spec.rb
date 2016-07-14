describe ManageIQ::Providers::Hawkular::MiddlewareManager::EventCatcher::Stream do
  subject do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    auth                 = AuthToken.new(:name     => "jdoe",
                                         :auth_key => "password",
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
      VCR.use_cassette(described_class.name.underscore.to_s,
                       :decode_compressed_response     => true) do # , :record => :new_episodes) do
        result = []
        subject.start
        subject.each_batch do |events|
          result = events
          subject.stop
        end
        expect(result.count).to be == 1
        expect(result[0].tags['miq.event_type']).to eq 'hawkular_event.critical'
      end
    end
  end
end
