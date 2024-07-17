RSpec.describe Ansible::Runner do
  before do
    pending("ansible-runner executable not available") unless described_class.available?
  end

  let(:env_vars)   { {} }
  let(:extra_vars) { {} }

  describe ".run" do
    it "runs a hello-world playbook" do
      response = Ansible::Runner.run(env_vars, extra_vars, File.join(__dir__, "runner/data/hello_world.yml"))

      expect(response.return_code).to eq(0), "ansible-runner failed with:\n#{response.stderr}"
      expect(response.human_stdout).to include('"msg": "Hello, world!"')
    end

    it "runs a hello-world-vault-encrypted playbook" do
      credential = FactoryBot.create(:embedded_ansible_vault_credential, :password => "vault")
      playbook   = File.join(__dir__, "runner/data/hello_world_vault_encrypted.yml")
      response   = Ansible::Runner.run(env_vars, extra_vars, playbook, :credentials => [credential.id])

      expect(response.return_code).to eq(0), "ansible-runner failed with:\n#{response.stderr}"
      expect(response.human_stdout).to include('"msg": "Hello World! (NOTE: This message has been encrypted with ansible-vault)"')
    end
  end

  describe ".run_async" do
    it "runs a hello-world playbook" do
      response = Ansible::Runner.run_async(env_vars, extra_vars, File.join(__dir__, "runner/data/hello_world.yml"))
      response = response.wait(10.seconds)

      expect(response.return_code).to eq(0), "ansible-runner failed with:\n#{response.stderr}"
      expect(response.human_stdout).to include('"msg": "Hello, world!"')
    end

    it "runs a hello-world-vault-encrypted playbook" do
      credential = FactoryBot.create(:embedded_ansible_vault_credential, :password => "vault")
      playbook   = File.join(__dir__, "runner/data/hello_world_vault_encrypted.yml")
      response   = Ansible::Runner.run_async(env_vars, extra_vars, playbook, :credentials => [credential.id])
      response = response.wait(10.seconds)

      expect(response.return_code).to eq(0), "ansible-runner failed with:\n#{response.stderr}"
      expect(response.human_stdout).to include('"msg": "Hello World! (NOTE: This message has been encrypted with ansible-vault)"')
    end
  end
end
