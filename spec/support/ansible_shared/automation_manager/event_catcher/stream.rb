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
      subject.instance_variable_set(:@last_activity, OpenStruct.new(:timestamp => '2016-01-01 01:00:00'))
      subject.instance_variable_set(:@poll_sleep, 0)
      expected_event = {
        "id"                 => 1,
        "type"               => "activity_stream",
        "url"                => "/api/v1/activity_stream/1/",
        "related"            => {
          "user" => [
            "/api/v1/users/1/"
          ]
        },
        "summary_fields"     => {
          "user" => [
            {
              "username"   => "admin",
              "first_name" => "",
              "last_name"  => "",
              "id"         => 1
            }
          ]
        },
        "timestamp"          => "2016-08-02T17:56:37.212874Z",
        "operation"          => "create",
        "changes"            => {
          "username"     => "admin",
          "first_name"   => "",
          "last_name"    => "",
          "is_active"    => true,
          "id"           => 1,
          "is_superuser" => true,
          "is_staff"     => true,
          "password"     => "hidden",
          "email"        => "admin@example.com",
          "date_joined"  => "2016-08-02 17:56:37.162225+00:00"
        },
        "object1"            => "user",
        "object2"            => "",
        "object_association" => ""
      }

      VCR.use_cassette(cassette_file) do
        subject.poll do |event|
          polled_event = event
          expect(polled_event.to_h).to eq(expected_event)
          subject.stop
        end
      end
    end
  end

  context ".filter" do
    it "converts timestamp to correct timeformat" do
      # It must be in YYYY-MM-DD HH:MM[:ss[.uuuuuu]][TZ]
      timestamps = {
        '2016-01-01 01:00:00'                  => '2016-01-01 01:00:00',
        '2017-03-10 19%3A31%3A26'              => '2017-03-10 00:00:00',
        Time.zone.parse('1975-12-31 01:01:01') => '1975-12-31 01:01:01',
      }
      timestamps.each do |input, converted|
        subject.instance_variable_set(:@last_activity, OpenStruct.new(:timestamp => input))
        expect(subject.send(:filter)[:timestamp__gt]).to eq(converted)
      end
    end
  end
end
