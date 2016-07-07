describe ManageIQ::Providers::Hawkular::MiddlewareManager::EventCatcher::Runner do
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
    described_class.new(:ems_id => ems.id)
  end

  before do
    allow_any_instance_of(ManageIQ::Providers::Hawkular::MiddlewareManager)
      .to receive_messages(:authentication_check => [true, ""])
    allow_any_instance_of(MiqWorker::Runner).to receive(:worker_initialization)
  end

  context "#whitelist" do
    require 'hawkular/hawkular_client'

    it "accepts event tagged with known event_type" do
      event      = ::Hawkular::Alerts::Event.new({})
      event.tags = {'miq.event_type' => 'hawkular_event.critical'}
      expect(subject.send(:whitelist?, event)).to be true
    end

    it "rejects event tagged with unknown event_type" do
      event      = ::Hawkular::Alerts::Event.new({})
      event.tags = {'miq.event_type' => 'hawkular_event.unknown'}
      expect(subject.send(:whitelist?, event)).to be false
    end

    it "rejects event without event_type tag" do
      event = ::Hawkular::Alerts::Event.new({})
      expect(subject.send(:whitelist?, event)).to be false
    end
  end

  context "#event_hash" do
    require 'hawkular/hawkular_client'

    it "properly converts event supplying only required fields" do
      event = ::Hawkular::Alerts::Event.new({})
      event.ctime = Time.now.to_i
      event.text = 'text message'
      event.tags = {'miq.event_type' => 'hawkular_event.critical'}

      hash = subject.send(:event_to_hash, event, 1)
      expect(hash).to be_an Hash
      expect(hash[:ems_id]).to eq 1
      expect(hash[:source]).to eq 'HAWKULAR'
      expect(hash[:timestamp]).to be_an Time
      expect(hash[:event_type]).to eq 'hawkular_event.critical'
      expect(hash[:message]).to eq 'text message'
      expect(hash[:middleware_ref]).to be_nil
      expect(hash[:middleware_type]).to be_nil
      expect(hash[:full_data]).to be_an String
    end

    it "properly converts event supplying optional fields" do
      event = ::Hawkular::Alerts::Event.new({})
      event.ctime = Time.now.to_i
      event.text    = 'text message'
      event.context = {'resource_path' => 'canonical_path', 'message' => 'context message'}
      event.tags    = {'miq.event_type' => 'hawkular_event.critical', 'miq.resource_type' => 'MiddlewareServer'}

      hash = subject.send(:event_to_hash, event, 1)
      expect(hash).to be_an Hash
      expect(hash[:ems_id]).to eq 1
      expect(hash[:source]).to eq 'HAWKULAR'
      expect(hash[:timestamp]).to be_an Time
      expect(hash[:event_type]).to eq 'hawkular_event.critical'
      expect(hash[:message]).to eq 'context message'
      expect(hash[:middleware_ref]).to eq 'canonical_path'
      expect(hash[:middleware_type]).to eq 'MiddlewareServer'
      expect(hash[:full_data]).to be_an String
    end
  end
end
