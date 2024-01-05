$LOAD_PATH << Rails.root.join("tools").to_s

require "fix_auth"

RSpec.describe FixAuth::FixConfigurationScript do
  let!(:configuration_script) { FactoryBot.create(:configuration_script, :credentials => credentials) }
  let(:legacy_key) { ManageIQ::Password::Key.new }
  let(:pass)       { "password" }
  let(:enc_old)    { ManageIQ::Password.encrypt(pass, legacy_key) }
  let(:options)    { {:legacy_key => legacy_key, :silent => true} }

  context "with nil credentials" do
    let(:credentials) { nil }

    it "does nothing" do
      FixAuth::FixConfigurationScript.run(options)
      expect(configuration_script.credentials).to be_nil
    end
  end

  context "with no v2 encrypted passwords in credentials" do
    let(:credentials) { {"foo" => "bar"} }

    it "does nothing" do
      FixAuth::FixConfigurationScript.run(options)
      expect(configuration_script.credentials).to eq(credentials)
    end
  end

  context "with a hash in the credentials value" do
    let(:credentials) { {"foo" => {"credential_ref" => "bar", "credential_field" => "password"}} }

    it "does nothing" do
      FixAuth::FixConfigurationScript.run(options)
      expect(configuration_script.credentials).to eq(credentials)
    end
  end

  context "with v2 encrypted passwords in credentials" do
    let(:credentials) { {"foo" => enc_old, "foo2" => enc_old, "bar" => "other"} }

    it "re-encrypts the passwords" do
      FixAuth::FixConfigurationScript.run(options)
      expect(configuration_script.reload.credentials["foo"]).to be_encrypted(pass)
      expect(configuration_script.reload.credentials["foo2"]).to be_encrypted(pass)
    end

    it "does nothing" do
      FixAuth::FixConfigurationScript.run(options)
      expect(configuration_script.reload.credentials["bar"]).to eq("other")
    end
  end
end
