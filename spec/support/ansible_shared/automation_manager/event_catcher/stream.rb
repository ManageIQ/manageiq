shared_examples_for "ansible event_catcher stream" do |cassette_file|
  let(:tower_url) { ENV['TOWER_URL'] || "https://dev-ansible-tower3.example.com/api/v1/" }
  let(:auth_userid) { ENV['TOWER_USER'] || 'testuser' }
  let(:auth_password) { ENV['TOWER_PASSWORD'] || 'secret' }

  let(:auth)                    { FactoryGirl.create(:authentication, :userid => auth_userid, :password => auth_password) }
  let(:automation_manager)      { provider.automation_manager }
  let(:provider) do
    FactoryGirl.create(:provider_ansible_tower,
                       :url        => tower_url,
                       :verify_ssl => false,).tap { |provider| provider.authentications << auth }
  end

  subject do
    described_class.new(automation_manager)
  end

  context "#poll" do
    it "yields valid events" do
      VCR.use_cassette(cassette_file) do
        last_activity = subject.send(:last_activity)
        # do something on tower that creates an activity in activity_stream
        provider.connect.api.credentials.create!(:name => 'test_stream', :user => 1)
        polled_event = nil
        subject.poll do |event|
          expect(event['id']).to eq(last_activity.id + 1)
          subject.stop
          polled_event = event
        end
        expect(subject.send(:last_activity).id).to eq(polled_event['id'])
      end
    end
  end
end
