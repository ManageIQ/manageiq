$LOAD_PATH << Rails.root.join("tools").to_s

require "fix_auth/auth_model"
require "fix_auth/auth_config_model"
require "fix_auth/models"

describe FixAuth::AuthConfigModel do
  let(:v1_key)  { MiqPassword.generate_symmetric }
  let(:pass)    { "password" }
  let(:enc_v1)  { MiqPassword.new.encrypt(pass, "v1", v1_key) }

  before do
    MiqPassword.add_legacy_key(v1_key, :v1)
  end

  after do
    MiqPassword.clear_keys
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

  context "#request_tasks" do
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
