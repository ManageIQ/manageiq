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

  describe ".decrypted_password_fields (private)" do
    let(:password)  { "pa$$word" }
    let(:encrypted) { MiqPassword.encrypt(password) }

    subject { described_class.send(:decrypted_password_fields) }

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
