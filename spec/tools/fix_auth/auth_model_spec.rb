$LOAD_PATH << Rails.root.join("tools").to_s

require "fix_auth/auth_model"
require "fix_auth/auth_config_model"
require "fix_auth/models"

RSpec.describe FixAuth::AuthModel do
  let(:pass)    { "password" }

  let(:enc_old) { ManageIQ::Password.encrypt(pass, legacy_key) }
  let(:enc_new) { ManageIQ::Password.encrypt(pass) }
  let(:enc_bad) { "v2:{5555555555555555555555==}" }

  let(:legacy_key) { ManageIQ::Password::Key.new }
  let(:options)    { {:legacy_key => legacy_key} }

  context "#authentications" do
    subject { FixAuth::FixAuthentication }
    let(:contenders) { subject.contenders.select(:name).collect(&:name) }
    let(:new_old) { subject.create(:name => "new_old", :password => enc_new, :auth_key => enc_old) }
    let(:old_new) { subject.create(:name => "old_new", :password => enc_old, :auth_key => enc_new) }
    let(:old)     { subject.create(:name => "old", :password => enc_old) }
    let(:bad)     { subject.create(:name => "bad", :password => enc_bad) }
    let(:blank)   { subject.create(:name => "blank") }
    let(:plain)   { subject.create(:name => "plain", :password => "nope") }

    it "should read column_names" do
      expect(subject.column_names).to include("id", "resource_id", "created_on")
    end

    it "should determine available_columns" do
      expect(subject.available_columns).to eq(%w[password auth_key])
    end

    it "should limit available_columns when not all columns are available" do
      allow(subject).to receive_messages(:column_names => %w[password id])
      expect(subject.available_columns).to eq(%w[password])
    end

    it "should build selection criteria (non selects)" do
      expect(subject.selection_criteria).to match(/password.*OR.*auth_key/)
    end

    it "should not find empty records" do
      blank.save!
      expect(contenders).not_to include(blank.name)
    end

    it "should find records with encrypted passwords" do
      [old, blank].each(&:save!)
      expect(contenders).to include(old.name)
      expect(contenders).not_to include(blank.name)
    end

    it "should find viable records among mixed mode records" do
      [new_old, old_new].each(&:save!)
      expect(contenders).to include(new_old.name)
      expect(contenders).to include(old_new.name)
    end

    context "#recrypt" do
      it "should not upgrade blank column" do
        subject.fix_passwords(blank, options)
        expect(blank).not_to be_password_changed
      end

      it "should upgrade old columns" do
        subject.fix_passwords(old, options)
        expect(old).to be_password_changed
      end

      it "should not encrypt plaintext columns" do
        subject.fix_passwords(plain, options)
        expect(plain).to_not be_password_changed
      end

      it "should raise exception for bad encryption" do
        expect { subject.fix_passwords(bad, options) }.to raise_error(ManageIQ::Password::PasswordError)
      end

      it "should replace for bad encryption" do
        subject.fix_passwords(bad, options.merge(:invalid => "other"))
        expect(bad.password).to be_encrypted("other")
      end

      context "with the rare case where recryption succeeds but returns garbage" do
        # NOTE: This legacy key only returns garbage specifically with the
        #   built-in v2_key.dev and the plaintext string "password", which is
        #   why it is redeclared here.  If this password is changed, a new
        #   colliding legacy key will need to be found.
        let(:pass)       { "password" }
        let(:legacy_key) { ManageIQ::Password::Key.new(nil, "XamduEwrkgMSeLjl+LQeutAWsLgKi3tR1mdEtclDPyM=") }

        it "should upgrade the column" do
          subject.fix_passwords(old_new, options)
          expect(old_new.password).to be_encrypted(pass)
          expect(old_new.auth_key).to be_encrypted(pass)
        end
      end
    end

    context "#hardcode" do
      it "should upgrade old columns" do
        subject.fix_passwords(old, options.merge(:hardcode => "newpass"))
        expect(old.password).to be_encrypted("newpass")
        expect(old.auth_key).to be_blank
      end
    end
  end

  context "#miq_database" do
    subject { FixAuth::FixMiqDatabase }
    let(:old)   { subject.create(:session_secret_token => enc_old) }
    let(:newer) { subject.create(:session_secret_token => enc_new) }
    let(:bad)   { subject.create(:session_secret_token => enc_bad) }

    it "uses random numbers for hardcode" do
      subject.fix_passwords(old, options.merge(:hardcode => "newpass"))
      expect(old.session_secret_token).to be_encrypted
      expect(ManageIQ::Password.decrypt(old.session_secret_token)).to_not eq "newpass"
      expect(old.session_secret_token).not_to eq(enc_old)
    end

    it "uses random numbers for invalid" do
      subject.fix_passwords(bad, options.merge(:invalid => "newpass"))
      expect(bad.session_secret_token).to be_encrypted
      expect(ManageIQ::Password.decrypt(bad.session_secret_token)).to_not eq "newpass"
      expect(bad.session_secret_token).not_to eq(enc_old)
    end

    it "upgrades" do
      expect(subject.fix_passwords(old, options).session_secret_token).to   eq(enc_new)
      expect(subject.fix_passwords(newer, options).session_secret_token).to eq(enc_new)
    end
  end

  context "#miq_ae_values" do
    subject { FixAuth::FixMiqAeValue }

    let(:pass_field) { FixAuth::FixMiqAeField.new(:name => "pass", :datatype => "password") }
    let(:old)   { subject.create(:field => pass_field, :value => enc_old) }
    let(:newer) { subject.create(:field => pass_field, :value => enc_new) }

    it "should update with complex contenders" do
      old # make sure record exists
      subject.run(options.merge(:silent => true))
      expect(old.reload.value).to   eq(enc_new)
      expect(newer.reload.value).to eq(enc_new)
    end
  end

  context "#settings_change" do
    subject { FixAuth::FixSettingsChange }
    let(:old)   { subject.create(:key => "/old/password", :value => enc_old) }
    let(:newer) { subject.create(:key => "/new/password", :value => enc_new) }
    let(:bad)   { subject.create(:key => "/bad/password", :value => enc_bad) }

    it "with hardcode" do
      subject.fix_passwords(old, options.merge(:hardcode => pass))
      expect(old.value).to eq(enc_new)
    end

    it "with invalid" do
      subject.fix_passwords(bad, options.merge(:invalid => pass))
      expect(bad.value).to eq(enc_new)
    end

    it "upgrades" do
      expect(subject.fix_passwords(old, options).value).to   eq(enc_new)
      expect(subject.fix_passwords(newer, options).value).to eq(enc_new)
    end
  end
end
