require "spec_helper"

$LOAD_PATH << Rails.root.join("tools")

require "fix_auth/auth_model"
require "fix_auth/auth_config_model"
require "fix_auth/models"

describe FixAuth::AuthModel do
  let(:pass)    { "password" }
  let(:enc_v1)  { MiqPassword.new.send(:encrypt_version_1, pass) }
  let(:enc_v2)  { MiqPassword.new.send(:encrypt_version_2, pass) }
  let(:bad_v2)  { "v2:{5555555555555555555555==}" }
  let(:enc_leg) { MiqPassword.v0_key.encrypt64(pass) }

  before do
    MiqPassword.v0_key ||= CryptString.new(nil, "AES-128-CBC", "9999999999999999", "5555555555555555")
    MiqPassword.v1_key ||= EzCrypto::Key.generate(:algorithm => "aes-256-cbc")
  end

  after do
    MiqPassword.v0_key = nil
    MiqPassword.v1_key = nil
  end

  context "#authentications" do
    subject { FixAuth::FixAuthentication }
    let(:contenders) { subject.contenders.collect(&:name) }

    # NOTE: these are not created unless you reference them
    # if you want to always create them use let!(:var) {} instead
    let(:v1_v2)  { subject.create(:name => "v2_v1", :password => enc_v2, :auth_key => enc_v1) }
    let(:v2_v1)  { subject.create(:name => "v1_v2", :password => enc_v1, :auth_key => enc_v2) }
    let(:v1)     { subject.create(:name => "v1", :password => enc_v1) }
    let(:v2)     { subject.create(:name => "v2", :password => enc_v2) }
    let(:badv2)  { subject.create(:name => "badv2", :password => bad_v2) }
    let(:leg)    { subject.create(:name => "lg", :password => enc_leg) }
    let(:nls)    { subject.create(:name => "nls") }
    let(:not_c)  { subject.create(:name => "notc", :password => "nope") }

    it "should read column_names" do
      expect(subject.column_names).to include("id", "resource_id", "created_on")
    end

    it "should determine available_columns" do
      expect(subject.available_columns).to eq(%w(password auth_key))
    end

    it "should limit available_columns when not all columns are available" do
      subject.stub(:column_names => %w(password id))
      expect(subject.available_columns).to eq(%w(password))
    end

    it "should build selection criteria (non selects)" do
      expect(subject.selection_criteria).to match(/OR/)
      expect(subject.selection_criteria).to match(/password.*!~ 'v2.*OR.*auth_key.*!~ 'v2/)
    end

    it "should build selection criteria (non selects)" do
      expect(subject.selection_criteria(true)).to match(/OR/)
      expect(subject.selection_criteria(true)).not_to match(/password.*!~ 'v2.*OR.*auth_key.*!~ 'v2/)
      expect(subject.selection_criteria(true)).to match(/password.*<>.*''.*OR.*auth_key.*<>.*''/)
    end

    it "should not find empty records" do
      nls.save!
      expect(contenders).not_to include(nls.name)
    end

    it "should find records with encrypted passwords" do
      [v1, v2, leg, nls].each(&:save!)
      expect(contenders).to include(v1.name, leg.name)
      expect(contenders).not_to include(v2.name, nls.name)
    end

    it "finds records already encryped when requested" do
      [v1, v2].each(&:save!)
      expect(subject.contenders(true).collect(&:name)).to include(v2.name)
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

      it "should upgrade legacy columns" do
        subject.fix_passwords(leg)
        expect(leg).to be_password_changed
        expect(leg).not_to be_auth_key_changed
        expect(leg.password).to be_encrypted(pass)
        expect(leg.password).to be_encrypted_version(2)
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
        expect { subject.fix_passwords(badv2) }.to raise_error("not decryptable string")
      end

      it "should replace for bad encryption" do
        subject.fix_passwords(badv2, :invalid => "other")
        expect(badv2.password).to be_encrypted("other")
      end
    end

    context "#hardcode" do
      it "should upgrade legacy columns" do
        subject.fix_passwords(leg, :hardcode => "newpass")
        expect(leg.password).to be_encrypted("newpass")
        expect(leg.password).to be_encrypted_version(2)
        expect(leg.auth_key).to be_blank
      end

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
    let(:v1) { subject.create(:field => pass_field, :value => enc_v1) }

    it "should update with complex contenders" do
      v1 # make sure record exists
      subject.run(:silent => true)
      expect(v1.reload.value).to be_encrypted_version(2)
    end
  end
end
