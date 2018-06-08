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
      end.to raise_error(described_class::ConfigurationInvalid)
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

    it "with a change with string keys" do
      described_class.save!(miq_server, "api" => {"token_ttl" => "1.hour"})

      miq_server.reload
      expect(miq_server.settings_changes.count).to eq 1
      expect(miq_server.settings_changes.first).to have_attributes(
        :key   => "/api/token_ttl",
        :value => "1.hour"
      )
    end

    it "with a change with mixed keys" do
      described_class.save!(miq_server, "api" => {:token_ttl => "1.hour"})

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
          :mode         => "ldap",
          :ldaphost     => "localhost",
          :bind_pwd     => password,
          :user_proxies => [{:bind_pwd => password}]
        }
      )

      miq_server.reload

      change = miq_server.settings_changes.find_by(:key => "/authentication/bind_pwd")
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

    context "deleting entries" do
      let(:server_value) { 1 }
      let(:zone_value)   { 2 }

      let(:reset)     { ::Vmdb::Settings::RESET_COMMAND }
      let(:reset_all) { ::Vmdb::Settings::RESET_ALL_COMMAND }

      let(:second_server) { FactoryGirl.create(:miq_server, :zone => miq_server.zone) }

      before do
        MiqRegion.seed

        described_class.save!(miq_server, :api => {:token_ttl => server_value}, :session => {:timeout => server_value})
        described_class.save!(miq_server, :api => {:new_key => "new value"})
        described_class.save!(second_server, :api => {:token_ttl => server_value}, :session => {:timeout => server_value})

        described_class.save!(miq_server.zone, :api => {:token_ttl => zone_value}, :session => {:timeout => zone_value})
        described_class.save!(miq_server, :array => [:element1 => 1, :element2 => 2])
        expect(SettingsChange.count).to eq 8
      end

      context "magic value <<reset>>" do
        it "deletes key-value for specific key for the resource if specified on leaf level" do
          described_class.save!(miq_server, :api => {:token_ttl => reset})

          expect(SettingsChange.count).to eq 7
          expect(miq_server.settings_changes.find_by(:key => "/api/token_ttl")).to be nil
          expect(Vmdb::Settings.for_resource(miq_server).api.new_key).to eq "new value"
          expect(Vmdb::Settings.for_resource(second_server).api.token_ttl).to eq server_value
        end

        it "deletes current node and all sub-nodes for the resource if specified on node level" do
          described_class.save!(miq_server, :api => reset)

          expect(SettingsChange.count).to eq 6
          expect(miq_server.settings_changes.where("key LIKE ?", "/api%").count).to eq 0
          expect(Vmdb::Settings.for_resource(miq_server).api.new_key).to eq nil
          expect(Vmdb::Settings.for_resource(second_server).api.token_ttl).to eq server_value
        end

        it "deletes new key-value settings not present in defaul yaml" do
          described_class.save!(miq_server, :api => {:new_key => reset})
          expect(Vmdb::Settings.for_resource(miq_server).api.new_key).to eq nil
        end

        it "deletes array" do
          described_class.save!(miq_server, :array => reset)
          expect(Vmdb::Settings.for_resource(miq_server).array).to be nil
        end

        it "passes validation" do
          described_class.save!(miq_server, :session => {:timeout => reset})
          expect(Vmdb::Settings.for_resource(miq_server).session.timeout).to eq zone_value
        end
      end

      context "magic value <<reset_all>>" do
        it "deletes all key-value for specific key for all resource if specified on leaf levelher" do
          described_class.save!(miq_server, :api => {:token_ttl => reset_all})

          expect(SettingsChange.where("key LIKE ?", "/api/token_ttl").count).to eq 0
          expect(SettingsChange.where("key LIKE ?", "/api%").count).to eq 1
          expect(SettingsChange.where("key LIKE ?", "/session%").count).to eq 3
        end

        it "deletes specific node and all sub-nodes for all resources if specified on node level" do
          described_class.save!(miq_server, :api => reset_all)

          expect(SettingsChange.where("key LIKE ?", "/api%").count).to eq 0
          expect(SettingsChange.where("key LIKE ?", "/session%").count).to eq 3
        end

        it "passes validation" do
          described_class.save!(miq_server, :session => {:timeout => reset_all})
          expect(SettingsChange.where("key LIKE ?", "/session%").count).to eq 0
        end
      end
    end
  end

  describe "save_yaml!" do
    let(:miq_server) { FactoryGirl.create(:miq_server) }

    it "saves the settings" do
      data = {:api => {:token_ttl => "1.day"}}.to_yaml
      described_class.save_yaml!(miq_server, data)

      miq_server.reload

      expect(miq_server.settings_changes.count).to eq 1
      expect(miq_server.settings_changes.first).to have_attributes(:key   => "/api/token_ttl",
                                                                   :value => "1.day")
    end

    it "handles incoming unencrypted values" do
      password  = "pa$$word"
      encrypted = MiqPassword.encrypt(password)

      data = {:authentication => {:bind_pwd => password}}.to_yaml
      described_class.save_yaml!(miq_server, data)

      miq_server.reload

      expect(miq_server.settings_changes.count).to eq 1
      expect(miq_server.settings_changes.first).to have_attributes(:key   => "/authentication/bind_pwd",
                                                                   :value => encrypted)
    end

    it "handles incoming encrypted values" do
      password  = "pa$$word"
      encrypted = MiqPassword.encrypt(password)

      data = {:authentication => {:bind_pwd => encrypted}}.to_yaml
      described_class.save_yaml!(miq_server, data)

      miq_server.reload

      expect(miq_server.settings_changes.count).to eq 1
      expect(miq_server.settings_changes.first).to have_attributes(:key   => "/authentication/bind_pwd",
                                                                   :value => encrypted)
    end

    {
      "syntax"     => "--- -", # invalid YAML
      "non-syntax" => "xxx"    # valid YAML, but invalid config
    }.each do |type, contents|
      it "catches #{type} errors" do
        expect { described_class.save_yaml!(miq_server, contents) }.to raise_error(described_class::ConfigurationInvalid) do |err|
          expect(err.errors.size).to eq 1
          expect(err.errors[:contents]).to start_with("File contents are malformed")
          expect(err.message).to include("contents: File contents are malformed")
        end
      end
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

    it "applies settings from up the hierarchy: Region -> Zone -> Server" do
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

      settings = Vmdb::Settings.for_resource(MiqServer.new(:zone => server.zone))
      expect(settings.api.token_ttl).to eq "4.hour"
    end
  end

  describe ".for_resource_yaml" do
    it "fetches the yaml with changes" do
      miq_server = FactoryGirl.create(:miq_server)
      described_class.save!(miq_server, :api => {:token_ttl => "1.day"})

      yaml = described_class.for_resource_yaml(miq_server)
      expect(yaml).to_not include("Config::Options")

      hash = YAML.load(yaml)
      expect(hash).to be_kind_of Hash
      expect(hash.fetch_path(:api, :token_ttl)).to eq "1.day"
    end

    it "ensures passwords are encrypted" do
      password  = "pa$$word"
      encrypted = MiqPassword.encrypt(password)

      miq_server = FactoryGirl.create(:miq_server)
      described_class.save!(miq_server, :authentication => {:bind_pwd => password})

      yaml = described_class.for_resource_yaml(miq_server)

      hash = YAML.load(yaml)
      expect(hash.fetch_path(:authentication, :bind_pwd)).to eq encrypted
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
