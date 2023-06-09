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
  end
end
