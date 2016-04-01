require "spec_helper"

describe Vmdb::Settings do
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

    it "with a previous change, now not specified" do
      miq_server.settings_changes.create!(:key => "/api/token_ttl", :value => "1.hour")

      described_class.save!(miq_server, {})

      expect(miq_server.reload.settings_changes.count).to eq 0
    end

    it "with a previous change, now back to the default" do
      default = Settings.api.token_ttl
      miq_server.settings_changes.create!(:key => "/api/token_ttl", :value => "1.hour")

      described_class.save!(miq_server, :api => {:token_ttl => default})

      expect(miq_server.reload.settings_changes.count).to eq 0
    end

    it "with a previous change, now to a new value" do
      change = miq_server.settings_changes.create!(:key => "/api/token_ttl", :value => "1.hour")

      described_class.save!(miq_server, :api => {:token_ttl => "2.hours"})

      miq_server.reload
      expect(miq_server.settings_changes.count).to eq 1
      expect(miq_server.settings_changes.first).to have_attributes(
        :id    => change.id,
        :key   => "/api/token_ttl",
        :value => "2.hours"
      )
    end

    it "with a mix of changes" do
      change  = miq_server.settings_changes.create!(:key => "/api/token_ttl", :value => "1.hour")
      _delete = miq_server.settings_changes.create!(:key => "/api/authentication_timeout", :value => "1.hour")

      described_class.save!(miq_server,
        :api => {:token_ttl => "2.hours"},
        :drift_states => {:history => {:keep_drift_states => "1.hour"}}
      )

      miq_server.reload
      expect(miq_server.settings_changes.count).to eq 2
      # Updated
      expect(miq_server.settings_changes.find_by(:key => "/api/token_ttl")).to have_attributes(
        :id    => change.id,
        :value => "2.hours"
      )
      # Added
      expect(miq_server.settings_changes.find_by(:key => "/drift_states/history/keep_drift_states")).to have_attributes(
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
  end
end
