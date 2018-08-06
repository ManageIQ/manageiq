describe Ansible::Runner do
  let(:uuid)       { "201ac780-7bf4-0136-3b9e-54e1ad8b3cf4" }
  let(:env_vars)   { {"ENV1" => "VAL1", "ENV2" => "VAL2"} }
  let(:extra_vars) { {"id" => uuid} }

  describe ".run" do
    let(:playbook) { "/path/to/my/playbook" }
    before { expect(File).to receive(:exist?).with(playbook).and_return(true) }

    it "calls launch with expected arguments" do
      expected_extra_vars = "--extra-vars\\ \\\\\\{\\\\\\\"id\\\\\\\":\\\\\\\"#{uuid}\\\\\\\"\\\\\\}"

      expected_command_line = [
        "ansible-runner run",
        "--json --playbook /path/to/my/playbook --ident result --hosts localhost --cmdline #{expected_extra_vars}"
      ]

      expect(AwesomeSpawn).to receive(:launch)
        .with(env_vars, a_string_including(*expected_command_line), {})

      described_class.run(env_vars, extra_vars, playbook)
    end

    context "with special characters" do
      let(:env_vars) { {"ENV1" => "pa$%w0rd!'"} }
      let(:extra_vars) { {"name" => "john's server"} }

      it "calls launch with expected arguments" do
        expected_extra_vars = "--extra-vars\\ \\\\\\{\\\\\\\"name\\\\\\\":\\\\\\\"john\\\\\\'s\\\\\\ server\\\\\\\"\\\\\\}"
        expected_command_line = [
          "ansible-runner run",
          "--json --playbook /path/to/my/playbook --ident result --hosts localhost --cmdline #{expected_extra_vars}"
        ]

        expect(AwesomeSpawn).to receive(:launch)
          .with(env_vars, a_string_including(*expected_command_line), {})

        described_class.run(env_vars, extra_vars, playbook)
      end
    end
  end

  describe ".run_async" do
    let(:playbook) { "/path/to/my/playbook" }
    before { expect(File).to receive(:exist?).with(playbook).and_return(true) }

    it "calls ansible-runner with start" do
      expected_extra_vars = "--extra-vars\\ \\\\\\{\\\\\\\"id\\\\\\\":\\\\\\\"201ac780-7bf4-0136-3b9e-54e1ad8b3cf4\\\\\\\"\\\\\\}"
      expected_command_line = [
        "ansible-runner start",
        "--json --playbook #{playbook} --ident result --hosts localhost --cmdline #{expected_extra_vars}"
      ]

      expect(AwesomeSpawn).to receive(:launch)
        .with(env_vars, a_string_including(*expected_command_line), {})

      result = described_class.run_async(env_vars, extra_vars, playbook)
      expect(result).kind_of?(Ansible::Runner::ResponseAsync)
    end
  end

  describe ".run_queue" do
    let(:playbook) { "/path/to/my/playbook" }
    let(:zone)     { FactoryGirl.create(:zone) }
    let(:user)     { FactoryGirl.create(:user) }

    it "queues Ansible::Runner.run in the right zone" do
      described_class.run_queue(env_vars, extra_vars, playbook, user.name, :zone => zone.name)

      expect(MiqQueue.count).to eq(1)
      expect(MiqQueue.first.zone).to eq(zone.name)
    end
  end

  describe ".run_role" do
    let(:role_name) { "my-custom-role" }
    let(:role_path) { "/path/to/my/roles" }
    before { expect(File).to receive(:exist?).with(File.join(role_path)).and_return(true) }

    it "runs ansible-runner with the role" do
      expected_command_line = [
        "ansible-runner run",
        "--extra-vars\\ \\\\\\{\\\\\\\"id\\\\\\\":\\\\\\\"201ac780-7bf4-0136-3b9e-54e1ad8b3cf4\\\\\\\"\\\\\\}"
      ]

      expect(AwesomeSpawn).to receive(:launch)
        .with(env_vars, a_string_including(*expected_command_line), {})
      described_class.run_role(env_vars, extra_vars, role_name, :roles_path => role_path)
    end
  end

  describe ".run_role_async" do
    let(:role_name) { "my-custom-role" }
    let(:role_path) { "/path/to/my/roles" }
    before { expect(File).to receive(:exist?).with(File.join(role_path)).and_return(true) }

    it "runs ansible-runner with the role" do
      expected_command_line = [
        "ansible-runner start",
        "--extra-vars\\ \\\\\\{\\\\\\\"id\\\\\\\":\\\\\\\"201ac780-7bf4-0136-3b9e-54e1ad8b3cf4\\\\\\\"\\\\\\}"
      ]

      expect(AwesomeSpawn).to receive(:launch)
        .with(env_vars, a_string_including(*expected_command_line), {})
      described_class.run_role_async(env_vars, extra_vars, role_name, :roles_path => role_path)
    end
  end

  describe ".run_role_queue" do
    let(:role_name) { "my-custom-role" }
    let(:role_path) { "/path/to/my/roles" }
    let(:zone)      { FactoryGirl.create(:zone) }
    let(:user)      { FactoryGirl.create(:user) }

    it "queues Ansible::Runner.run in the right zone" do
      described_class.run_role_queue(env_vars, extra_vars, role_name, user.name, {:zone => zone.name}, :roles_path => role_path)

      expect(MiqQueue.count).to eq(1)
      expect(MiqQueue.first.zone).to eq(zone.name)
    end
  end
end
