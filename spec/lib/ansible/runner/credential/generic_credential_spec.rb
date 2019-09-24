require 'ansible/runner'
require 'ansible/runner/credential'

RSpec.describe Ansible::Runner::GenericCredential do
  it ".auth_type is an empty string" do
    expect(described_class.auth_type).to eq("")
  end

  context "with a credential object" do
    around do |example|
      Dir.mktmpdir("ansible-runner-credential-test") do |dir|
        @base_dir = dir
        example.run
      end
    end

    let(:cred) do
      auth = FactoryBot.create(:authentication)
      described_class.new(auth.id, @base_dir)
    end

    it "#command_line is an empty hash" do
      expect(cred.command_line).to eq({})
    end

    it "#env_vars is an empty hash" do
      expect(cred.env_vars).to eq({})
    end

    it "#extra_vars is an empty hash" do
      expect(cred.extra_vars).to eq({})
    end

    it "#write_config_files does not write a file" do
      password_file = File.join(@base_dir, "env", "passwords")
      cred.write_config_files
      expect(File.exist?(password_file)).to be_falsey
    end
  end
end
