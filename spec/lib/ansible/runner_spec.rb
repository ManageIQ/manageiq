RSpec.describe Ansible::Runner do
  let(:uuid)       { "201ac780-7bf4-0136-3b9e-54e1ad8b3cf4" }
  let(:env_vars)   { {"ENV1" => "VAL1", "ENV2" => "VAL2"} }
  let(:extra_vars) { {"id" => uuid} }
  let(:tags)       { "tag" }
  let(:ee_image)   { "docker.io/manageiq/ansible-ee:latest" }

  let(:docker_runner) { instance_double(Floe::ContainerRunner::Docker) }
  let(:runner_context) { {"container_ref" => "floe-ansible-ee-abc123", "container_state" => {"Running" => false, "ExitCode" => 0}} }

  before do
    stub_settings_merge(:embedded_ansible => {:execution_environment_image => ee_image})
    # Stub both the build_container_runner factory and the direct .new call used
    # by ResponseAsync#runner so both paths resolve to the same double.
    allow(described_class).to receive(:build_container_runner).and_return(docker_runner)
    allow(Floe::ContainerRunner::Docker).to receive(:new).and_return(docker_runner)
    # Ensure docker_runner.class.name returns the real class name so that
    # ResponseAsync can constantize it back to Floe::ContainerRunner::Docker.
    allow(docker_runner).to receive(:class).and_return(Floe::ContainerRunner::Docker)
    # Unit tests use fake paths that don't exist on disk; skip the actual copy.
    allow(described_class).to receive(:copy_content)
  end

  describe ".available?" do
    it "when execution_environment_image is set" do
      allow(described_class).to receive(:container_runner_class).and_return(Floe::ContainerRunner::Docker)
      expect(described_class.available?).to be true
    end

    it "when execution_environment_image is blank" do
      stub_settings_merge(:embedded_ansible => {:execution_environment_image => ""})
      expect(described_class.available?).to be false
    end

    it "when no container runtime is available" do
      allow(described_class).to receive(:container_runner_class).and_return(nil)
      expect(described_class.available?).to be false
    end
  end

  describe ".run" do
    let(:playbook) { "/path/to/my/playbook.yml" }

    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(playbook).and_return(true)
    end

    it "calls run_async! and writes the required files" do
      expect(docker_runner).to receive(:run_async!) do |resource, env, _secrets, _context, volumes:, command:|
        expect(resource).to eq("docker://#{ee_image}")
        expect(env).to match(a_hash_including(env_vars))
        expect(command).to eq(["sh", "-c", "ansible-runner run /runner --ident result --json --playbook playbook.yml"])

        vol = volumes.first
        expect(vol[:container_path]).to eq("/runner")

        base_dir = vol[:host_path]
        hosts    = File.read(File.join(base_dir, "inventory", "hosts"))
        expect(hosts).to eq("localhost")

        extravars = JSON.parse(File.read(File.join(base_dir, "env", "extravars")))
        expect(extravars).to eq("id" => uuid, "ansible_connection" => "local")

        expect(File.exist?(File.join(base_dir, "env", "cmdline"))).to be_falsey

        runner_context
      end

      expect(docker_runner).to receive(:status!).with(runner_context).at_least(:once)
      expect(docker_runner).to receive(:running?).with(runner_context).at_least(:once).and_return(false)
      expect(docker_runner).to receive(:output).with(runner_context).and_return("")
      expect(docker_runner).to receive(:success?).with(runner_context).and_return(true)
      expect(docker_runner).to receive(:cleanup).with(runner_context)

      described_class.run(env_vars, extra_vars, playbook)
    end

    it "calls run with expected tag" do
      expect(docker_runner).to receive(:run_async!) do |_resource, _env, _secrets, _context, volumes:, **|
        base_dir = volumes.first[:host_path]
        cmdline  = File.read(File.join(base_dir, "env", "cmdline"))
        expect(cmdline).to eq("--tags #{tags}")
        runner_context
      end

      expect(docker_runner).to receive(:status!).with(runner_context).at_least(:once)
      expect(docker_runner).to receive(:running?).with(runner_context).at_least(:once).and_return(false)
      expect(docker_runner).to receive(:output).with(runner_context).and_return("")
      expect(docker_runner).to receive(:success?).with(runner_context).and_return(true)
      expect(docker_runner).to receive(:cleanup).with(runner_context)

      described_class.run(env_vars, extra_vars, playbook, :tags => tags)
    end

    it "clamps verbosity at 5 flags in the container command" do
      expect(docker_runner).to receive(:run_async!) do |_resource, _env, _secrets, _context, command:, **|
        expect(command.last).to include("-vvvvv")
        expect(command.last).not_to include("-vvvvvv")
        runner_context
      end

      expect(docker_runner).to receive(:status!).with(runner_context).at_least(:once)
      expect(docker_runner).to receive(:running?).with(runner_context).at_least(:once).and_return(false)
      expect(docker_runner).to receive(:output).with(runner_context).and_return("")
      expect(docker_runner).to receive(:success?).with(runner_context).and_return(true)
      expect(docker_runner).to receive(:cleanup).with(runner_context)

      described_class.run(env_vars, extra_vars, playbook, :verbosity => 6)
    end

    it "calls run with become options" do
      expect(docker_runner).to receive(:run_async!) do |_resource, _env, _secrets, _context, volumes:, **|
        base_dir = volumes.first[:host_path]
        cmdline  = File.read(File.join(base_dir, "env", "cmdline"))
        expect(cmdline).to eq("--become")
        runner_context
      end

      expect(docker_runner).to receive(:status!).with(runner_context).at_least(:once)
      expect(docker_runner).to receive(:running?).with(runner_context).at_least(:once).and_return(false)
      expect(docker_runner).to receive(:output).with(runner_context).and_return("")
      expect(docker_runner).to receive(:success?).with(runner_context).and_return(true)
      expect(docker_runner).to receive(:cleanup).with(runner_context)

      described_class.run(env_vars, extra_vars, playbook, :become_enabled => true)
    end

    context "with special characters" do
      let(:env_vars)   { {"ENV1" => "pa$%w0rd!'"} }
      let(:extra_vars) { {"name" => "john's server"} }

      it "passes through special character values correctly" do
        expect(docker_runner).to receive(:run_async!) do |_resource, env, _secrets, _context, volumes:, **|
          expect(env).to match(a_hash_including(env_vars))

          base_dir  = volumes.first[:host_path]
          extravars = JSON.parse(File.read(File.join(base_dir, "env", "extravars")))
          expect(extravars).to eq("name" => "john's server", "ansible_connection" => "local")
          runner_context
        end

        expect(docker_runner).to receive(:status!).with(runner_context).at_least(:once)
        expect(docker_runner).to receive(:running?).with(runner_context).at_least(:once).and_return(false)
        expect(docker_runner).to receive(:output).with(runner_context).and_return("")
        expect(docker_runner).to receive(:success?).with(runner_context).and_return(true)
        expect(docker_runner).to receive(:cleanup).with(runner_context)

        described_class.run(env_vars, extra_vars, playbook)
      end
    end
  end

  describe ".run_async" do
    let(:playbook) { "/path/to/my/playbook.yml" }

    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(playbook).and_return(true)
    end

    it "returns a ResponseAsync without waiting" do
      expect(docker_runner).to receive(:run_async!) do |_resource, _env, _secrets, _context, command:, **|
        expect(command.last).to include("--playbook playbook.yml")
        runner_context
      end

      result = described_class.run_async(env_vars, extra_vars, playbook)
      expect(result).to be_a(Ansible::Runner::ResponseAsync)
    end
  end

  describe ".run_queue" do
    let(:playbook) { "/path/to/my/playbook.yml" }
    let(:zone)     { FactoryBot.create(:zone) }
    let(:user)     { FactoryBot.create(:user) }

    it "queues Ansible::Runner.run in the right zone" do
      described_class.run_queue(env_vars, extra_vars, playbook, user.name, {:zone => zone.name})

      expect(MiqQueue.count).to eq(1)
      expect(MiqQueue.first.zone).to eq(zone.name)
    end
  end

  describe ".run_role" do
    let(:role_name) { "my-custom-role" }
    let(:role_path) { "/path/to/my/roles" }

    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(role_path).and_return(true)
    end

    it "passes the role name and roles-path to the container command" do
      expect(docker_runner).to receive(:run_async!) do |_resource, _env, _secrets, _context, command:, **|
        expect(command.last).to include("--role #{role_name} --roles-path /runner/roles")
        runner_context
      end

      expect(docker_runner).to receive(:status!).with(runner_context).at_least(:once)
      expect(docker_runner).to receive(:running?).with(runner_context).at_least(:once).and_return(false)
      expect(docker_runner).to receive(:output).with(runner_context).and_return("")
      expect(docker_runner).to receive(:success?).with(runner_context).and_return(true)
      expect(docker_runner).to receive(:cleanup).with(runner_context)

      described_class.run_role(env_vars, extra_vars, role_name, :roles_path => role_path)
    end

    it "passes tags via cmdline file" do
      expect(docker_runner).to receive(:run_async!) do |_resource, _env, _secrets, _context, volumes:, **|
        base_dir = volumes.first[:host_path]
        cmdline  = File.read(File.join(base_dir, "env", "cmdline"))
        expect(cmdline).to eq("--tags #{tags}")
        runner_context
      end

      expect(docker_runner).to receive(:status!).with(runner_context).at_least(:once)
      expect(docker_runner).to receive(:running?).with(runner_context).at_least(:once).and_return(false)
      expect(docker_runner).to receive(:output).with(runner_context).and_return("")
      expect(docker_runner).to receive(:success?).with(runner_context).and_return(true)
      expect(docker_runner).to receive(:cleanup).with(runner_context)

      described_class.run_role(env_vars, extra_vars, role_name, :roles_path => role_path, :tags => tags)
    end
  end

  describe ".run_role_async" do
    let(:role_name) { "my-custom-role" }
    let(:role_path) { "/path/to/my/roles" }

    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(role_path).and_return(true)
    end

    it "returns a ResponseAsync" do
      expect(docker_runner).to receive(:run_async!) do |_resource, _env, _secrets, _context, command:, **|
        expect(command.last).to include("--role #{role_name}")
        runner_context
      end

      result = described_class.run_role_async(env_vars, extra_vars, role_name, :roles_path => role_path)
      expect(result).to be_a(Ansible::Runner::ResponseAsync)
    end
  end

  describe ".run_role_queue" do
    let(:role_name) { "my-custom-role" }
    let(:role_path) { "/path/to/my/roles" }
    let(:zone)      { FactoryBot.create(:zone) }
    let(:user)      { FactoryBot.create(:user) }

    it "queues Ansible::Runner.run_role in the right zone" do
      queue_args = {:zone => zone.name}
      described_class.run_role_queue(env_vars, extra_vars, role_name, user.name, queue_args, :roles_path => role_path)

      expect(MiqQueue.count).to eq(1)
      expect(MiqQueue.first.zone).to eq(zone.name)
    end
  end

  describe ".container_runner_class (private)" do
    before { described_class.instance_variable_set(:@container_runner_class, nil) }
    after  { described_class.instance_variable_set(:@container_runner_class, nil) }

    it "returns Floe::ContainerRunner::Kubernetes when podified" do
      allow(MiqEnvironment::Command).to receive(:is_podified?).and_return(true)
      expect(described_class.send(:container_runner_class)).to eq(Floe::ContainerRunner::Kubernetes)
    end

    it "returns Floe::ContainerRunner::Podman when podman is available" do
      allow(MiqEnvironment::Command).to receive(:is_podified?).and_return(false)
      allow(described_class).to receive(:system).with("which podman >/dev/null 2>&1").and_return(true)
      expect(described_class.send(:container_runner_class)).to eq(Floe::ContainerRunner::Podman)
    end

    it "returns Floe::ContainerRunner::Docker when only docker is available" do
      allow(MiqEnvironment::Command).to receive(:is_podified?).and_return(false)
      allow(described_class).to receive(:system).with("which podman >/dev/null 2>&1").and_return(false)
      allow(described_class).to receive(:system).with("which docker >/dev/null 2>&1").and_return(true)
      expect(described_class.send(:container_runner_class)).to eq(Floe::ContainerRunner::Docker)
    end

    it "returns nil when no runtime is available" do
      allow(MiqEnvironment::Command).to receive(:is_podified?).and_return(false)
      allow(described_class).to receive(:system).with("which podman >/dev/null 2>&1").and_return(false)
      allow(described_class).to receive(:system).with("which docker >/dev/null 2>&1").and_return(false)
      expect(described_class.send(:container_runner_class)).to be_nil
    end

    it "memoizes the result" do
      allow(MiqEnvironment::Command).to receive(:is_podified?).and_return(false)
      allow(described_class).to receive(:system).with("which podman >/dev/null 2>&1").and_return(true)
      2.times { described_class.send(:container_runner_class) }
      expect(described_class).to have_received(:system).once
    end
  end

  describe ".build_container_runner (private)" do
    it "instantiates the memoized container_runner_class" do
      allow(described_class).to receive(:build_container_runner).and_call_original
      allow(described_class).to receive(:container_runner_class).and_return(Floe::ContainerRunner::Docker)
      allow(Floe::ContainerRunner::Docker).to receive(:new).and_call_original
      runner = described_class.send(:build_container_runner)
      expect(runner).to be_a(Floe::ContainerRunner::Docker)
    end
  end

  describe ".build_runner_cmd (private)" do
    let(:base_dir) { Dir.mktmpdir("ansible-runner-cmd-spec") }
    after { FileUtils.rm_rf(base_dir) }

    it "builds playbook command" do
      cmd = described_class.send(:build_runner_cmd, base_dir, {:playbook => "/path/to/my/playbook.yml"}, 0)
      expect(cmd).to eq(["sh", "-c", "ansible-runner run /runner --ident result --json --playbook playbook.yml"])
    end

    it "builds playbook command with roles/requirements.yml" do
      roles_dir = FileUtils.mkdir_p(File.join(base_dir, "project", "roles")).first
      File.write(File.join(roles_dir, "requirements.yml"), "---\n")

      cmd = described_class.send(:build_runner_cmd, base_dir, {:playbook => "/path/to/my/playbook.yml"}, 0)
      expect(cmd).to eq(["sh", "-c", "ansible-galaxy install -r /runner/project/roles/requirements.yml -p /runner/project/roles && ansible-runner run /runner --ident result --json --playbook playbook.yml"])
    end

    it "builds playbook command with project requirements.yml" do
      project_dir = FileUtils.mkdir_p(File.join(base_dir, "project")).first
      File.write(File.join(project_dir, "requirements.yml"), "---\n")

      cmd = described_class.send(:build_runner_cmd, base_dir, {:playbook => "/path/to/my/playbook.yml"}, 0)
      expect(cmd).to eq(["sh", "-c", "ansible-galaxy install -r /runner/project/requirements.yml -p /runner/project/roles && ansible-runner run /runner --ident result --json --playbook playbook.yml"])
    end

    it "builds role command" do
      cmd = described_class.send(:build_runner_cmd, base_dir, {:role => "my-role", :roles_path => "/some/path", :role_skip_facts => true}, 0)
      expect(cmd).to eq(["sh", "-c", "ansible-runner run /runner --ident result --json --role my-role --roles-path /runner/roles --role-skip-facts"])
    end

    it "builds role command with roles/requirements.yml" do
      roles_dir = FileUtils.mkdir_p(File.join(base_dir, "roles")).first
      File.write(File.join(roles_dir, "requirements.yml"), "---\n")

      cmd = described_class.send(:build_runner_cmd, base_dir, {:role => "my-role", :roles_path => "/some/path", :role_skip_facts => true}, 0)
      expect(cmd).to eq(["sh", "-c", "ansible-galaxy install -r /runner/roles/requirements.yml -p /runner/roles && ansible-runner run /runner --ident result --json --role my-role --roles-path /runner/roles --role-skip-facts"])
    end

    it "appends verbosity flags" do
      cmd = described_class.send(:build_runner_cmd, base_dir, {:playbook => "/path/to/my/playbook.yml"}, 3)
      expect(cmd.last).to include("-vvv")
    end

    it "clamps verbosity to 5 flags" do
      cmd = described_class.send(:build_runner_cmd, base_dir, {:playbook => "/path/to/my/playbook.yml"}, 99)
      expect(cmd.last).to include("-vvvvv")
    end
  end
end
