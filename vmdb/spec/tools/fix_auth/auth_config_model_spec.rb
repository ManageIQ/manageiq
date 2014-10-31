require "spec_helper"

$LOAD_PATH << Rails.root.join("tools")

require "fix_auth/auth_model"
require "fix_auth/auth_config_model"
require "fix_auth/models"

describe FixAuth::AuthConfigModel do
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

  context "#configurations" do
    subject { FixAuth::FixConfiguration }
    let(:contenders) { subject.contenders }

    let(:config_with_v1_key) do
      subject.create(:typ => 'vmdb', :settings => YAML.dump(:production => {:password => enc_v1}))
    end

    let(:config_with_bad_password) do
      subject.create(:typ => 'vmdb', :settings => YAML.dump(:production => {:password => bad_v2}))
    end

    let(:config_with_non_vmdb) do
      subject.create(:typ => 'event_handling', :settings => YAML.dump(:production => {:password => enc_v1}))
    end

    it "should only find vmdb records" do
      config_with_v1_key
      config_with_non_vmdb
      expect(contenders).to include(config_with_v1_key)
      expect(contenders).not_to include(config_with_non_vmdb)
    end

    it "should upgrade" do
      subject.fix_passwords(config_with_v1_key)
      expect(config_with_v1_key).to be_settings_changed
      new_settings = YAML.load(config_with_v1_key.settings)
      expect(new_settings['production']['password']).to be_encrypted_version(2)
      expect(new_settings['production']['password']).to be_encrypted(pass)
    end

    it "hardcodes entry" do
      subject.fix_passwords(config_with_v1_key, :hardcode => "otherpass")
      expect(config_with_v1_key).to be_settings_changed
      new_settings = YAML.load(config_with_v1_key.settings)
      expect(new_settings['production']['password']).to be_encrypted_version(2)
      expect(new_settings['production']['password']).to be_encrypted("otherpass")
    end

    it "should fail on bad passwords" do
      expect { subject.fix_passwords(config_with_bad_password) }.to raise_error
    end

    it "should replace bad passwords" do
      subject.fix_passwords(config_with_bad_password, :invalid => "replacement")
      new_settings = YAML.load(config_with_bad_password.settings)
      expect(new_settings['production']['password']).to be_encrypted("replacement")
    end
  end

  context "#requests" do
    subject { FixAuth::FixMiqRequest }
    let(:request) do
      subject.create(
        :type    => 'MiqProvisionRequest',
        :options => YAML.dump(
          :dialog                  => {
            :'password::special' => enc_v1,
          },
          :root_password           => enc_v1,
          :sysprep_password        => enc_v1,
          :sysprep_domain_password => enc_v1
        )
      )
    end

    it "upgrades request (find with prefix, dont stringify keys)" do
      subject.fix_passwords(request)
      expect(request).to be_changed
      new_options = YAML.load(request.options)
      expect(new_options[:dialog]['password::special'.to_sym]).to be_encrypted(pass)
      expect(new_options[:dialog]['password::special'.to_sym]).to be_encrypted_version(2)

      expect(new_options[:root_password]).to be_encrypted(pass)
      expect(new_options[:root_password]).to be_encrypted_version(2)
      expect(new_options[:sysprep_password]).to be_encrypted(pass)
      expect(new_options[:sysprep_password]).to be_encrypted_version(2)
      expect(new_options[:sysprep_domain_password]).to be_encrypted(pass)
      expect(new_options[:sysprep_domain_password]).to be_encrypted_version(2)
    end
  end

  context "#requests" do
    subject { FixAuth::FixMiqRequestTask }
    let(:request) do
      subject.create(
        :type    => 'MiqProvisionRequest',
        :options => YAML.dump(
          :dialog                  => {
            :'password::special' => enc_v1,
          },
          :root_password           => enc_v1,
          :sysprep_password        => enc_v1,
          :sysprep_domain_password => enc_v1
        )
      )
    end

    it "upgrades request (find with prefix, dont stringify keys)" do
      subject.fix_passwords(request)
      expect(request).to be_changed
      new_options = YAML.load(request.options)
      expect(new_options[:dialog]['password::special'.to_sym]).to be_encrypted(pass)
      expect(new_options[:dialog]['password::special'.to_sym]).to be_encrypted_version(2)

      expect(new_options[:root_password]).to be_encrypted(pass)
      expect(new_options[:root_password]).to be_encrypted_version(2)
      expect(new_options[:sysprep_password]).to be_encrypted(pass)
      expect(new_options[:sysprep_password]).to be_encrypted_version(2)
      expect(new_options[:sysprep_domain_password]).to be_encrypted(pass)
      expect(new_options[:sysprep_domain_password]).to be_encrypted_version(2)
    end
  end
end
