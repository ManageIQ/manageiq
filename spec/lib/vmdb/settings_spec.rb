require "spec_helper"

describe Vmdb::Settings do
  it ".walk" do
    stub_settings(:a => {:b => 'c'}, :d => {:e => {:f => 'g'}})

    walked = []
    described_class.walk do |key, value, path, settings|
      expect(settings).to be_kind_of(Config::Options)
      if Settings.keys.include?(key)
        expect(settings).to eq Settings
      else
        expect(settings).to eq Settings.deep_send(*path[0...-1])
      end

      expect(value).to be_kind_of(Config::Options) if %i(a d e).include?(key)

      walked << [key, value.try(:to_hash) || value, path]
    end

    expect(walked).to eq [
      [:a, {:b => 'c'},         [:a]],
      [:b, 'c',                 [:a, :b]],
      [:d, {:e => {:f => 'g'}}, [:d]],
      [:e, {:f => 'g'},         [:d, :e]],
      [:f, 'g',                 [:d, :e, :f]],
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

    it "encrypts password fields" do
      password  = "pa$$word"
      encrypted = MiqPassword.encrypt(password)

      described_class.save!(miq_server,
        :authentication => {
          :mode          => "amazon",
          :amazon_key    => "key",
          :amazon_secret => password
        }
      )

      change = miq_server.reload.settings_changes.find_by(:key => "/authentication/amazon_secret")
      expect(change.value).to eq encrypted
    end
  end

  describe ".decrypted_password_fields (private)" do
    let(:password)  { "pa$$word" }
    let(:encrypted) { MiqPassword.encrypt(password) }

    subject { described_class.send(:decrypted_password_fields, Settings) }

    it "with passwords in clear text" do
      stub_settings(:password => password)
      expect(subject).to eq(:password => password)
    end

    it "with passwords encrypted" do
      stub_settings(:password => encrypted)
      expect(subject).to eq(:password => password)
    end

    it "with passwords set to nil" do
      stub_settings(:password => nil)
      expect(subject).to eq({})
    end

    it "with passwords set to blank" do
      stub_settings(:password => "")
      expect(subject).to eq({})
    end

    it "ignores non-password keys" do
      stub_settings(:password => encrypted, :other => "other")
      expect(subject).to eq(:password => password)
    end

    it "handles deeply nested passwords" do
      stub_settings(:level1 => {:level2 => {:password => encrypted}})
      expect(subject).to eq(:level1 => {:level2 => {:password => password}})
    end

    it "decrypts all password keys" do
      encypted_hash = described_class::PASSWORD_FIELDS.map { |key| [key.to_sym, encrypted] }.to_h
      stub_settings(encypted_hash)

      password_hash = described_class::PASSWORD_FIELDS.map { |key| [key.to_sym, password] }.to_h
      expect(subject).to eq(password_hash)
    end
  end
end
