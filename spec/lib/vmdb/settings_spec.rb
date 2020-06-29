RSpec.describe Vmdb::Settings do
  describe ".dump_to_log_directory" do
    it "is called on top-level ::Settings.reload!" do
      expect(described_class).to receive(:dump_to_log_directory)

      ::Settings.reload!
    end

    it "writes them" do
      ::Settings.api.token_ttl = "1.minute"
      described_class.dump_to_log_directory(::Settings)

      dumped_yaml = YAML.load_file(described_class::DUMP_LOG_FILE)
      expect(dumped_yaml.fetch_path(:api, :token_ttl)).to eq "1.minute"
    end

    it "masks passwords" do
      ::Settings.authentication.bind_pwd = "pa$$w0rd"
      described_class.dump_to_log_directory(::Settings)

      dumped_yaml = YAML.load_file(described_class::DUMP_LOG_FILE)
      expect(dumped_yaml.fetch_path(:authentication, :bind_pwd)).to eq "********"
    end
  end

  describe ".walk" do
    it "traverses tree properly" do
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

    it "handles basic recursion (value == settings)" do
      y = YAML.load(<<~CONFIG)
        ---
        :hash:
        - &1
          A: *1
        CONFIG

      expect { described_class.walk(y) { |_k, _v, _p, _o| } }.not_to raise_error
    end

    it "handles hash recursion (embedded array == settings)" do
      s = {:a => []}
      s[:a] << s
      expect { described_class.walk(s) { |_k, _v, _p, _o| } }.not_to raise_error
    end

    it "handles array recursion (key == settings)" do
      s = []
      s << s
      expect { described_class.walk(s) { |_k, _v, _p, _o| } }.not_to raise_error
    end
  end

  describe ".save!" do
    let(:miq_server) { FactoryBot.create(:miq_server) }

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
      encrypted = ManageIQ::Password.encrypt(password)

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

    describe described_class::RESET_COMMAND do
      let(:server_value) { "server" }
      let(:zone_value)   { "zone" }
      let(:region_value) { "region" }
      let(:server_array_value) { [{:key1 => server_value}, {:key1 => server_value}] }
      let(:zone_array_value)   { [{:key1 => zone_value},   {:key1 => zone_value}] }

      let(:reset) { described_class::RESET_COMMAND }

      before do
        MiqRegion.seed

        described_class.save!(
          MiqRegion.first,
          :api     => {
            :token_ttl              => region_value,
            :authentication_timeout => region_value
          },
          :session => {:timeout => 2}
        )
        described_class.save!(
          miq_server.zone,
          :api   => {
            :token_ttl => zone_value
          },
          :array => zone_array_value
        )
        described_class.save!(
          miq_server,
          :api     => {
            :token_ttl              => server_value,
            :authentication_timeout => server_value,
            :new_key                => "new value"
          },
          :session => {:timeout => 1},
          :array   => server_array_value
        )
      end

      it "inherits a leaf-level value from the parent" do
        described_class.save!(miq_server, :api => {:token_ttl => reset})

        expect(described_class.for_resource(miq_server).api.token_ttl).to eq zone_value
      end

      it "inherits a node-level value from the parent" do
        described_class.save!(miq_server, :api => reset)

        expect(described_class.for_resource(miq_server).api.token_ttl).to eq zone_value
        expect(described_class.for_resource(miq_server).api.authentication_timeout).to eq region_value
      end

      it "inherits an array from the parent" do
        described_class.save!(miq_server, :array => reset)

        expect(described_class.for_resource(miq_server).to_hash[:array]).to eq zone_array_value
      end

      it "deletes a leaf-level value not present in the parent" do
        described_class.save!(miq_server, :api => {:new_key => reset})

        expect(described_class.for_resource(miq_server).api.new_key).to be_nil
        expect(miq_server.reload.settings_changes.where(:key => "/api/new_key")).to_not exist
      end

      it "deletes a leaf-level value not present in the parent when reset at the node level" do
        described_class.save!(miq_server, :api => reset)

        expect(described_class.for_resource(miq_server).api.new_key).to be_nil
        expect(described_class.for_resource(miq_server).api.token_ttl).to eq zone_value
        expect(miq_server.reload.settings_changes.where(:key => "/api/new_key")).to_not exist
      end

      it "deletes an array value not present in the parent" do
        described_class.save!(miq_server.zone, :array => reset)

        expect(described_class.for_resource(miq_server.zone).array).to be_nil
        expect(miq_server.zone.reload.settings_changes.where(:key => "/array")).to_not exist
      end

      it "at a parent level does not push down changes to children" do
        described_class.save!(miq_server.zone, :api => {:token_ttl => reset})

        expect(described_class.for_resource(miq_server.zone).api.token_ttl).to eq region_value
        expect(described_class.for_resource(miq_server).api.token_ttl).to eq server_value
      end

      it "passes validation" do
        described_class.save!(miq_server, :session => {:timeout => reset})

        expect(described_class.for_resource(miq_server).session.timeout).to eq 2
      end
    end
  end

  describe "save_yaml!" do
    let(:miq_server) { FactoryBot.create(:miq_server) }

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
      encrypted = ManageIQ::Password.encrypt(password)

      data = {:authentication => {:bind_pwd => password}}.to_yaml
      described_class.save_yaml!(miq_server, data)

      miq_server.reload

      expect(miq_server.settings_changes.count).to eq 1
      expect(miq_server.settings_changes.first).to have_attributes(:key   => "/authentication/bind_pwd",
                                                                   :value => encrypted)
    end

    it "handles incoming encrypted values" do
      password  = "pa$$word"
      encrypted = ManageIQ::Password.encrypt(password)

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
    let(:expected) { ManageIQ::Password.encrypt(initial) }

    include_examples "password handling"
  end

  describe ".decrypt_passwords!" do
    let(:method)   { :decrypt_passwords! }
    let(:initial)  { ManageIQ::Password.encrypt(expected) }
    let(:expected) { "pa$$word" }

    include_examples "password handling"
  end

  describe ".mask_passwords!" do
    let(:method)   { :mask_passwords! }
    let(:initial)  { "pa$$word" }
    let(:expected) { "********" }

    include_examples "password handling"
  end

  describe ".filter_passwords!" do
    it "removes the field from the settings" do
      stub_settings(:password => nil)
      filtered = described_class.filter_passwords!(Settings.to_h)
      expect(filtered.keys).to_not include(:password)
    end
  end

  describe ".for_resource" do
    let(:server) { FactoryBot.create(:miq_server) }

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

    context "on global region" do
      let(:key)                 { "yuri" }
      let(:value_region_remote) { "region_remote" }
      let(:value_server_remote) { "server_remote" }
      let(:value_zone_remote)   { "zone_remote" }

      before do
        Zone.seed
        @region_global = MiqRegion.first
        @region_remote = FactoryBot.create(:miq_region, :id => ApplicationRecord.id_in_region(1, @region_global.region + 1))
        @zone_remote   = FactoryBot.create(:zone, :id => ApplicationRecord.id_in_region(2, @region_remote.region))
        @server_remote = FactoryBot.create(:miq_server, :zone => @zone_remote, :id => ApplicationRecord.id_in_region(1, @region_remote.region))
        SettingsChange.create!(:id            => ApplicationRecord.id_in_region(1, @region_global.region),
                               :resource_id   => @region_global.id,
                               :resource_type => "MiqRegion",
                               :key           => "/#{key}",
                               :value         => "value from global region")
        zone_global = FactoryBot.create(:zone, :id => ApplicationRecord.id_in_region(1, @region_global.region))
        SettingsChange.create!(:id            => ApplicationRecord.id_in_region(2, @region_global.region),
                               :resource_id   => zone_global.id,
                               :resource_type => "Zone",
                               :key           => "/#{key}",
                               :value         => "value from global zone")
      end

      it "applies settings from remote sever if there are specified" do
        SettingsChange.create!(:id            => ApplicationRecord.id_in_region(1, @region_remote.region),
                               :resource_id   => @server_remote.id,
                               :resource_type => "MiqServer",
                               :key           => "/#{key}",
                               :value         => value_server_remote)
        expect(Vmdb::Settings.for_resource(@server_remote)[key]).to eq(value_server_remote)
      end

      it "applies settings from remote region if settings on remote server not specified" do
        SettingsChange.create!(:id            => ApplicationRecord.id_in_region(1, @region_remote.region),
                               :resource_id   => @region_remote.id,
                               :resource_type => "MiqRegion",
                               :key           => "/#{key}",
                               :value         => value_region_remote)
        expect(Vmdb::Settings.for_resource(@server_remote)[key]).to eq(value_region_remote)
      end

      it "applies settings from remote zone if settings on remote server not specified" do
        SettingsChange.create!(:id            => ApplicationRecord.id_in_region(1, @region_remote.region),
                               :resource_id   => @zone_remote.id,
                               :resource_type => "Zone",
                               :key           => "/#{key}",
                               :value         => value_zone_remote)
        expect(Vmdb::Settings.for_resource(@server_remote)[key]).to eq(value_zone_remote)
      end

      it "loads settings from correct level of hirerarchy" do
        SettingsChange.create!(:id            => ApplicationRecord.id_in_region(1, @region_remote.region),
                               :resource_id   => @region_remote.id,
                               :resource_type => "MiqRegion",
                               :key           => "/#{key}",
                               :value         => value_region_remote)
        SettingsChange.create!(:id            => ApplicationRecord.id_in_region(2, @region_remote.region),
                               :resource_id   => @zone_remote.id,
                               :resource_type => "Zone",
                               :key           => "/#{key}",
                               :value         => value_zone_remote)
        SettingsChange.create!(:id            => ApplicationRecord.id_in_region(3, @region_remote.region),
                               :resource_id   => @server_remote.id,
                               :resource_type => "MiqServer",
                               :key           => "/#{key}",
                               :value         => value_server_remote)

        expect(Vmdb::Settings.for_resource(@server_remote)[key]).to eq(value_server_remote)
        expect(Vmdb::Settings.for_resource(@zone_remote)[key]).to eq(value_zone_remote)
        expect(Vmdb::Settings.for_resource(@region_remote)[key]).to eq(value_region_remote)
      end
    end
  end

  describe ".for_resource_yaml" do
    it "fetches the yaml with changes" do
      miq_server = FactoryBot.create(:miq_server)
      described_class.save!(miq_server, :api => {:token_ttl => "1.day"})

      yaml = described_class.for_resource_yaml(miq_server)
      expect(yaml).to_not include("Config::Options")

      hash = YAML.load(yaml)
      expect(hash).to be_kind_of Hash
      expect(hash.fetch_path(:api, :token_ttl)).to eq "1.day"
    end

    it "ensures passwords are encrypted" do
      password  = "pa$$word"
      encrypted = ManageIQ::Password.encrypt(password)

      miq_server = FactoryBot.create(:miq_server)
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
