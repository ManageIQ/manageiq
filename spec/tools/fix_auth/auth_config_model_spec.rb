$LOAD_PATH << Rails.root.join("tools").to_s

require "fix_auth/auth_model"
require "fix_auth/auth_config_model"
require "fix_auth/models"

RSpec.describe FixAuth::AuthConfigModel do
  let(:pass)    { "password" }
  let(:enc_old) { ManageIQ::Password.new.encrypt(pass, "v2", legacy_key) }
  let(:enc_new) { ManageIQ::Password.encrypt(pass) }

  let(:legacy_key) { ManageIQ::Password::Key.new }
  let(:options)    { {:legacy_key => legacy_key} }

  before do
    ManageIQ::Password.keys["alt"] = legacy_key
  end

  after do
    ManageIQ::Password.clear_keys
  end

  context "#requests" do
    subject { FixAuth::FixMiqRequest }
    let(:request) do
      subject.create(
        :type    => 'MiqProvisionRequest',
        :options => YAML.dump(
          :dialog                  => {
            :'password::special' => enc_old,
          },
          :root_password           => enc_old,
          :sysprep_password        => enc_old,
          :sysprep_domain_password => enc_new
        )
      )
    end

    it "upgrades request (find with prefix, dont stringify keys)" do
      subject.fix_passwords(request)
      expect(request).to be_changed
      new_options = YAML.load(request.options)
      expect(new_options[:dialog]['password::special'.to_sym]).to be_encrypted(pass)

      expect(new_options[:root_password]).to be_encrypted(pass)
      expect(new_options[:sysprep_password]).to be_encrypted(pass)
      expect(new_options[:sysprep_domain_password]).to be_encrypted(pass)
    end
  end

  context "#request_tasks" do
    subject { FixAuth::FixMiqRequestTask }
    let(:request) do
      subject.create(
        :type    => 'MiqProvisionRequest',
        :options => YAML.dump(
          :dialog                  => {
            :'password::special' => enc_old,
          },
          :root_password           => enc_old,
          :sysprep_password        => enc_old,
          :sysprep_domain_password => enc_new
        )
      )
    end

    it "upgrades request (find with prefix, dont stringify keys)" do
      subject.fix_passwords(request)
      expect(request).to be_changed
      new_options = YAML.load(request.options)
      expect(new_options[:dialog]['password::special'.to_sym]).to be_encrypted(pass)

      expect(new_options[:root_password]).to be_encrypted(pass)
      expect(new_options[:sysprep_password]).to be_encrypted(pass)
      expect(new_options[:sysprep_domain_password]).to be_encrypted(pass)
    end
  end
end
