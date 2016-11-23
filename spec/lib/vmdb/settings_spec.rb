describe Vmdb::Settings do
  describe ".on_reload" do
    it "is called on top-level ::Settings.reload!" do
      expect(described_class).to receive(:on_reload)

      ::Settings.reload!
    end

    it "updates the last_loaded time" do
      Timecop.freeze(Time.now.utc) do
        expect(described_class.last_loaded).to_not eq(Time.now.utc)

        described_class.on_reload

        expect(described_class.last_loaded).to eq(Time.now.utc)
      end
    end

    context "dumping the settings to the log directory" do
      it "writes them" do
        ::Settings.api.token_ttl = "1.minute"
        described_class.on_reload

        dumped_yaml = YAML.load_file(described_class::DUMP_LOG_FILE)
        expect(dumped_yaml.fetch_path(:api, :token_ttl)).to eq "1.minute"
      end

      it "masks passwords" do
        ::Settings.authentication.bind_pwd = "pa$$w0rd"
        described_class.on_reload

        dumped_yaml = YAML.load_file(described_class::DUMP_LOG_FILE)
        expect(dumped_yaml.fetch_path(:authentication, :bind_pwd)).to eq "********"
      end
    end
  end

  it ".walk" do
    stub_settings(:a => {:b => 'c'}, :d => {:e => {:f => 'g'}}, :i => [{:j => 'k'}, {:l => 'm'}])

    walked = []
    described_class.walk do |key, value, path, owning|
      expect(owning).to be_kind_of(Config::Options)

      if %i(a d e).include?(key)
        expect(value).to be_kind_of(Config::Options)
        value = value.to_hash
      elsif %i(i).include?(key)
        expect(value).to be_kind_of(Array)
        value.each { |v| expect(v).to be_kind_of(Config::Options) }
        value = value.collect(&:to_hash)
      end

      walked << [key, value, path]
    end

    expect(walked).to eq [
      #key value                       path
      [:a, {:b => 'c'},                [:a]],
      [:b, 'c',                        [:a, :b]],
      [:d, {:e => {:f => 'g'}},        [:d]],
      [:e, {:f => 'g'},                [:d, :e]],
      [:f, 'g',                        [:d, :e, :f]],
      [:i, [{:j => 'k'}, {:l => 'm'}], [:i]],
      [:j, 'k',                        [:i, 0, :j]],
      [:l, 'm',                        [:i, 1, :l]],
    ]
  end

  describe ".save!" do
    let(:miq_server) { FactoryGirl.create(:miq_server) }

    it "does not allow invalid configuration values" do
      expect do
        described_class.save!(miq_server, :authentication => {:mode => "stuff"})
      end.to raise_error(RuntimeError, "configuration invalid")
    end

    it "with a change" do
      described_class.save!(miq_server, :api => {:token_ttl => "1.hour"})

      miq_server.reload
      expect(miq_server.settings_changes.count).to eq 1
      expect(miq_server.settings_changes.first).to have_attributes(
        :key   => "/api/token_ttl",
        :value => "1.hour"
      )
    end

    it "with a previous change, now back to the default" do
      default = Settings.api.token_ttl
      miq_server.settings_changes.create!(:key => "/api/token_ttl", :value => "1.hour")

      described_class.save!(miq_server, :api => {:token_ttl => default})

      expect(miq_server.reload.settings_changes.count).to eq 0
    end

    it "with a previous change, now to a new value" do
      update = miq_server.settings_changes.create!(:key => "/api/token_ttl", :value => "1.hour")

      described_class.save!(miq_server, :api => {:token_ttl => "2.hours"})

      miq_server.reload
      expect(miq_server.settings_changes.count).to eq 1
      expect(miq_server.settings_changes.first).to have_attributes(
        :id    => update.id,
        :key   => "/api/token_ttl",
        :value => "2.hours"
      )
    end

    it "with a mix of changes" do
      default = Settings.api.authentication_timeout
      update  = miq_server.settings_changes.create!(:key => "/api/token_ttl", :value => "1.hour")
      _delete = miq_server.settings_changes.create!(:key => "/api/authentication_timeout", :value => "1.hour")

      described_class.save!(miq_server,
        :api => {
          :token_ttl              => "2.hours", # Updated
          :authentication_timeout => default,   # Deleted (back to default)
        },
        :drift_states => {
          :history => {
            :keep_drift_states    => "1.hour"   # Added
          }
        }
      )

      miq_server.reload
      expect(miq_server.settings_changes.count).to eq 2

      changes = miq_server.settings_changes.order(:key)
      # Updated
      expect(changes[0]).to have_attributes(
        :id    => update.id,
        :key   => "/api/token_ttl",
        :value => "2.hours"
      )
      # Added
      expect(changes[1]).to have_attributes(
        :key   => "/drift_states/history/keep_drift_states",
        :value => "1.hour"
      )
    end

    it "with a previous change, now not specified" do
      miq_server.settings_changes.create!(:key => "/api/token_ttl", :value => "1.hour")

      described_class.save!(miq_server, {})

      miq_server.reload
      expect(miq_server.settings_changes.count).to eq 1
      expect(miq_server.settings_changes.first).to have_attributes(
        :key   => "/api/token_ttl",
        :value => "1.hour"
      )
    end

    it "with previous changes, but only specifying one of them" do
      miq_server.settings_changes.create!(:key => "/api/token_ttl", :value => "1.hour")
      miq_server.settings_changes.create!(:key => "/api/authentication_timeout", :value => "1.hours")

      described_class.save!(miq_server, :api => {:authentication_timeout => "2.hours"})

      miq_server.reload
      expect(miq_server.settings_changes.count).to eq 2

      changes = miq_server.settings_changes.order(:key)
      # Updated
      expect(changes[0]).to have_attributes(
        :key   => "/api/authentication_timeout",
        :value => "2.hours"
      )
      # Unchanged
      expect(changes[1]).to have_attributes(
        :key   => "/api/token_ttl",
        :value => "1.hour"
      )
    end

    it "with a change to an Array" do
      array_hash = {:log => {:collection => {:current => {:pattern => ["*.log"]}}}}
      described_class.save!(miq_server, array_hash)

      miq_server.reload
      expect(miq_server.settings_changes.count).to eq 1
      expect(miq_server.settings_changes.first).to have_attributes(
        :key   => "/log/collection/current/pattern",
        :value => ["*.log"]
      )
    end

    it "encrypts password fields" do
      password  = "pa$$word"
      encrypted = MiqPassword.encrypt(password)

      described_class.save!(miq_server,
        :authentication => {
          :mode          => "amazon",
          :amazon_key    => "key",
          :amazon_secret => password,
          :user_proxies  => [{:bind_pwd => password}]
        }
      )

      miq_server.reload

      change = miq_server.settings_changes.find_by(:key => "/authentication/amazon_secret")
      expect(change.value).to eq encrypted

      change = miq_server.settings_changes.find_by(:key => "/authentication/user_proxies")
      expect(change.value).to eq [{:bind_pwd => encrypted}]
    end

    it "saving settings for Zone does not change saved Region or Server settings" do
      MiqRegion.seed

      described_class.save!(miq_server.zone, :api => {:token_ttl => "2.hour"})
      miq_server.zone.reload
      expect(miq_server.zone.settings_changes.count).to eq 1
      expect(miq_server.zone.settings_changes.first).to have_attributes(:key   => "/api/token_ttl",
                                                                        :value => "2.hour")
      miq_server.reload
      expect(miq_server.settings_changes.count).to eq 0

      miq_server.miq_region.reload
      expect(miq_server.miq_region.settings_changes.count).to eq 0
    end

    it "saving settings for Region does not change saved Zone or Server settings" do
      MiqRegion.seed

      described_class.save!(miq_server.zone.miq_region, :api => {:token_ttl => "3.hour"})
      miq_server.zone.miq_region.reload

      expect(miq_server.miq_region.settings_changes.count).to eq 1
      expect(miq_server.miq_region.settings_changes.first).to have_attributes(:key   => "/api/token_ttl",
                                                                              :value => "3.hour")
      miq_server.reload
      expect(miq_server.settings_changes.count).to eq 0

      miq_server.zone.reload
      expect(miq_server.zone.settings_changes.count).to eq 0
    end
  end

  shared_examples_for "password handling" do
    subject do
      described_class.send(method, Settings)
      Settings.to_hash
    end

    it "with password" do
      stub_settings(:password => initial)
      expect(subject).to eq(:password => expected)
    end

    it "with converted password" do
      stub_settings(:password => expected)
      expect(subject).to eq(:password => expected)
    end

    it "with password set to nil" do
      stub_settings(:password => nil)
      expect(subject).to eq(:password => nil)
    end

    it "with password set to blank" do
      stub_settings(:password => "")
      expect(subject).to eq(:password => "")
    end

    it "ignores non-password keys" do
      stub_settings(:password => initial, :other => "other")
      expect(subject).to eq(:password => expected, :other => "other")
    end

    it "handles deeply nested passwords" do
      stub_settings(:level1 => {:level2 => {:password => initial}})
      expect(subject).to eq(:level1 => {:level2 => {:password => expected}})
    end

    it "handles deeply nested passwords in arrays" do
      stub_settings(:level1 => {:level2 => [{:password => initial}]})
      expect(subject).to eq(:level1 => {:level2 => [{:password => expected}]})
    end

    it "handles all password keys" do
      initial_hash = described_class::PASSWORD_FIELDS.map { |key| [key.to_sym, initial] }.to_h
      stub_settings(initial_hash)

      expected_hash = described_class::PASSWORD_FIELDS.map { |key| [key.to_sym, expected] }.to_h
      expect(subject).to eq(expected_hash)
    end
  end

  describe ".encrypt_passwords!" do
    let(:method)   { :encrypt_passwords! }
    let(:initial)  { "pa$$word" }
    let(:expected) { MiqPassword.encrypt(initial) }

    include_examples "password handling"
  end

  describe ".decrypt_passwords!" do
    let(:method)   { :decrypt_passwords! }
    let(:initial)  { MiqPassword.encrypt(expected) }
    let(:expected) { "pa$$word" }

    include_examples "password handling"
  end

  describe ".mask_passwords!" do
    let(:method)   { :mask_passwords! }
    let(:initial)  { "pa$$word" }
    let(:expected) { "********" }

    include_examples "password handling"
  end

  describe ".for_resource" do
    let(:server) { FactoryGirl.create(:miq_server) }

    it "without database changes" do
      settings = Vmdb::Settings.for_resource(server)
      expect(settings.api.token_ttl).to eq "10.minutes"
    end

    it "with database changes" do
      server.settings_changes.create!(:key => "/api/token_ttl", :value => "2.minutes")
      settings = Vmdb::Settings.for_resource(server)
      expect(settings.api.token_ttl).to eq "2.minutes"
    end

    it "with database changes on an Array" do
      server.settings_changes.create!(:key => "/log/collection/current/pattern", :value => ["*.log"])
      settings = Vmdb::Settings.for_resource(server)
      expect(settings.log.collection.current.pattern).to eq ["*.log"]
    end

    it "can load settings on each level from Region -> Zone -> Server hierarchy" do
      MiqRegion.seed
      described_class.save!(server.zone.miq_region, :api => {:token_ttl => "3.hour"})
      described_class.save!(server.zone, :api => {:token_ttl => "4.hour"})
      described_class.save!(server, :api => {:token_ttl => "5.hour"})

      settings = Vmdb::Settings.for_resource(server)
      expect(settings.api.token_ttl).to eq "5.hour"

      settings = Vmdb::Settings.for_resource(server.zone)
      expect(settings.api.token_ttl).to eq "4.hour"

      settings = Vmdb::Settings.for_resource(server.zone.miq_region)
      expect(settings.api.token_ttl).to eq "3.hour"
    end

    it "applied settings from hierarchy Region -> Zone -> Server" do
      MiqRegion.seed

      described_class.save!(server.zone.miq_region, :api => {:token_ttl => "3.hour"})
      settings = Vmdb::Settings.for_resource(server)
      expect(settings.api.token_ttl).to eq "3.hour"

      described_class.save!(server.zone, :api => {:token_ttl => "4.hour"})
      settings = Vmdb::Settings.for_resource(server)
      expect(settings.api.token_ttl).to eq "4.hour"

      described_class.save!(server, :api => {:token_ttl => "5.hour"})
      settings = Vmdb::Settings.for_resource(server)
      expect(settings.api.token_ttl).to eq "5.hour"
    end
  end

  it "with .local file" do
    stub_local_settings_file(
      Rails.root.join("config/settings/test.local.yml"),
      {"api" => {"token_ttl" => "2.minutes"}}.to_yaml
    )

    expect(::Settings.api.token_ttl).to eq("2.minutes")
  end
end
