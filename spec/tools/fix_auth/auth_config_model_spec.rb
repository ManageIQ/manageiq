require "spec_helper"

$LOAD_PATH << Rails.root.join("tools")

require "fix_auth/auth_model"
require "fix_auth/auth_config_model"
require "fix_auth/models"

describe FixAuth::AuthConfigModel do
  let(:v1_key)  { MiqPassword.generate_symmetric }
  let(:pass)    { "password" }
  let(:enc_v1)  { MiqPassword.new.encrypt(pass, "v1", v1_key) }
  let(:bad_v2)  { "v2:{5555555555555555555555==}" }

  before do
    MiqPassword.add_legacy_key(v1_key)
  end

  after do
    MiqPassword.clear_keys
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
      expect { subject.fix_passwords(config_with_bad_password) }.to raise_error(MiqPassword::MiqPasswordError)
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
