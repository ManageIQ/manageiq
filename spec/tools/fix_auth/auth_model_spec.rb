$LOAD_PATH << Rails.root.join("tools").to_s

require "fix_auth/auth_model"
require "fix_auth/auth_config_model"
require "fix_auth/models"

describe FixAuth::AuthModel do
  let(:v0_key)  { MiqPassword::Key.new("AES-128-CBC", Base64.encode64("9999999999999999"), Base64.encode64("5555555555555555")) }
  let(:v1_key)  { MiqPassword.generate_symmetric }
  let(:pass)    { "password" }
  let(:enc_v1)  { MiqPassword.new.encrypt(pass, "v1", v1_key) }
  let(:enc_v2)  { MiqPassword.new.encrypt(pass) }
  let(:bad_v2)  { "v2:{5555555555555555555555==}" }

  before do
    MiqPassword.add_legacy_key(v1_key, :v1)
  end

  after do
    MiqPassword.clear_keys
  end

  context "#authentications" do
    subject { FixAuth::FixAuthentication }
    let(:contenders) { subject.contenders.select(:name).collect(&:name) }
    let(:v1_v2)  { subject.create(:name => "v2_v1", :password => enc_v2, :auth_key => enc_v1) }
    let(:v2_v1)  { subject.create(:name => "v1_v2", :password => enc_v1, :auth_key => enc_v2) }
    let(:v1)     { subject.create(:name => "v1", :password => enc_v1) }
    let(:v2)     { subject.create(:name => "v2", :password => enc_v2) }
    let(:badv2)  { subject.create(:name => "badv2", :password => bad_v2) }
    let(:nls)    { subject.create(:name => "nls") }
    let(:not_c)  { subject.create(:name => "notc", :password => "nope") }

    it "should read column_names" do
      expect(subject.column_names).to include("id", "resource_id", "created_on")
    end

    it "should determine available_columns" do
      expect(subject.available_columns).to eq(%w(password auth_key))
    end

    it "should limit available_columns when not all columns are available" do
      allow(subject).to receive_messages(:column_names => %w(password id))
      expect(subject.available_columns).to eq(%w(password))
    end

    it "should build selection criteria (non selects)" do
      expect(subject.selection_criteria).to match(/password.*OR.*auth_key/)
    end

    it "should not find empty records" do
      nls.save!
      expect(contenders).not_to include(nls.name)
    end

    it "should find records with encrypted passwords" do
      [v2, nls].each(&:save!)
      expect(contenders).to include(v2.name)
      expect(contenders).not_to include(nls.name)
    end

    it "should find viable records among mixed mode records" do
      [v1_v2, v2_v1].each(&:save!)
      expect(contenders).to include(v1_v2.name)
      expect(contenders).to include(v2_v1.name)
    end

    context "#recrypt" do
      it "should not upgrade blank column" do
        subject.fix_passwords(nls)
        expect(nls).not_to be_password_changed
      end

      it "should upgrade v1 columns" do
        subject.fix_passwords(v1)
        expect(v1).to be_password_changed
        expect(v1.password).to be_encrypted_version(2)
      end

      it "should skip over non-encrypted columns" do
        subject.fix_passwords(not_c)
        expect(not_c).not_to be_password_changed
      end

      it "should raise exception for bad encryption" do
        expect { subject.fix_passwords(badv2) }.to raise_error(MiqPassword::MiqPasswordError)
      end

      it "should replace for bad encryption" do
        subject.fix_passwords(badv2, :invalid => "other")
        expect(badv2.password).to be_encrypted("other")
      end
    end

    context "#hardcode" do
      it "should upgrade v2 columns" do
        subject.fix_passwords(v2, :hardcode => "newpass")
        expect(v2.password).to be_encrypted("newpass")
        expect(v2.password).to be_encrypted_version(2)
        expect(v2.auth_key).to be_blank
      end
    end
  end

  context "#miq_database" do
    subject { FixAuth::FixMiqDatabase }
    let(:v1)  { subject.create(:session_secret_token => enc_v1) }
    let(:v2)  { subject.create(:session_secret_token => enc_v2) }
    let(:bad) { subject.create(:session_secret_token => bad_v2) }

    it "uses random numbers for hardcode" do
      subject.fix_passwords(v1, :hardcode => "newpass")
      expect(v1.session_secret_token).to be_encrypted_version(2)
      expect(v1.session_secret_token).not_to be_encrypted("newpass")
      expect(v1.session_secret_token).not_to eq(enc_v2)
    end

    it "uses random numbers for invalid" do
      subject.fix_passwords(bad, :invalid => "newpass")
      expect(bad.session_secret_token).to be_encrypted_version(2)
      expect(bad.session_secret_token).not_to be_encrypted("newpass")
      expect(bad.session_secret_token).not_to eq(enc_v2)
    end

    it "upgrades" do
      expect(subject.fix_passwords(v1).session_secret_token).to eq(enc_v2)
      expect(subject.fix_passwords(v2).session_secret_token).to eq(enc_v2)
    end
  end

  context "#miq_ae_values" do
    subject { FixAuth::FixMiqAeValue }

    let(:pass_field) { FixAuth::FixMiqAeField.new(:name => "pass", :datatype => "password") }
    let(:v2) { subject.create(:field => pass_field, :value => enc_v2) }

    it "should update with complex contenders" do
      v2 # make sure record exists
      subject.run(:silent => true)
      expect(v2.reload.value).to be_encrypted_version(2)
    end
  end

  context "#settings_change" do
    subject { FixAuth::FixSettingsChange }
    let(:v1)  { subject.create(:key => "/v1/password", :value => enc_v1) }
    let(:v2)  { subject.create(:key => "/v2/password", :value => enc_v2) }
    let(:bad) { subject.create(:key => "/bad/password", :value => bad_v2) }

    it "with hardcode" do
      subject.fix_passwords(v1, :hardcode => pass)
      expect(v1.value).to eq(enc_v2)
    end

    it "with invalid" do
      subject.fix_passwords(bad, :invalid => pass)
      expect(bad.value).to eq(enc_v2)
    end

    it "upgrades" do
      expect(subject.fix_passwords(v1).value).to eq(enc_v2)
      expect(subject.fix_passwords(v2).value).to eq(enc_v2)
    end
  end
end
