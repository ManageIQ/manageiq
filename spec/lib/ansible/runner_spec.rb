RSpec.describe Ansible::Runner do
  let(:uuid)       { "201ac780-7bf4-0136-3b9e-54e1ad8b3cf4" }
  let(:env_vars)   { {"ENV1" => "VAL1", "ENV2" => "VAL2"} }
  let(:extra_vars) { {"id" => uuid} }
  let(:tags)       { "tag" }
  let(:result)     { AwesomeSpawn::CommandResult.new("ansible-runner", "output", "", 100, "0") }

  let(:venv_python_path)   { "/var/lib/manageiq/venv/python3.12/site-packages" }
  let(:venv_bin_path)      { "/var/lib/manageiq/venv/bin" }
  let(:python_path)        { "/usr/local/lib64/python3.12/site-packages:/usr/local/lib/python3.12/site-packages:/usr/lib64/python3.12/site-packages:/usr/lib/python3.12/site-packages" }
  let(:system_path)        { "/opt/manageiq/manageiq-gemset/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin" }
  let(:runner_python_path) { [venv_python_path, python_path].join(":") }
  let(:runner_path)        { [venv_bin_path, system_path].join(":") }
  let(:runner_env)         { {"PYTHONPATH" => runner_python_path, "PATH" => runner_path} }

  let(:ansible_version_raw) do
    <<~EOF
      ansible [core 2.18.6]
        config file = None
        configured module search path = ['/root/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
        ansible python module location = /var/lib/manageiq/venv/lib64/python3.12/site-packages/ansible
        ansible collection location = /root/.ansible/collections:/usr/share/ansible/collections
        executable location = /var/lib/manageiq/venv/bin/ansible
        python version = 3.12.10 (main, Apr  9 2025, 00:00:00) [GCC 11.5.0 20240719 (Red Hat 11.5.0-5)] (/var/lib/manageiq/venv/bin/python3.12)
        jinja version = 3.1.6
        libyaml = True
    EOF
  end

  describe ".available?" do
    before { begin; described_class.remove_instance_variable(:@available); rescue NameError; end }
    after  { begin; described_class.remove_instance_variable(:@available); rescue NameError; end }

    it "when available" do
      expect(described_class).to receive(:runner_env).and_return(runner_env)
      expect(described_class).to receive(:system).with(runner_env, /^which ansible-runner/).and_return(true)

      expect(described_class.available?).to be true
    end

    it "when not available" do
      expect(described_class).to receive(:runner_env).and_return(runner_env)
      expect(described_class).to receive(:system).with(runner_env, /^which ansible-runner/).and_return(false)

      expect(described_class.available?).to be false
    end
  end

  describe ".run" do
    let(:playbook) { "/path/to/my/playbook" }
    before do
      allow(described_class).to receive(:runner_env).and_return(runner_env)

      allow(described_class).to receive(:wait_for).and_yield
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(playbook).and_return(true)
    end

    it "calls run and writes the required files" do
      expect(AwesomeSpawn).to receive(:run) do |command, options|
        expect(command).to eq("ansible-runner")
        expect(options[:env]).to match a_hash_including(env_vars)

        method, dir, json, args = options[:params]

        expect(method).to eq("run")
        expect(json).to   eq(:json)
        expect(args).to   eq(:ident => "result", :playbook => "playbook", :project_dir => "/path/to/my")

        hosts = File.read(File.join(dir, "inventory", "hosts"))
        expect(hosts).to eq("localhost")

        extravars = JSON.parse(File.read(File.join(dir, "env", "extravars")))
        expect(extravars).to eq("id" => uuid, "ansible_connection" => "local")

        expect(File.exist?(File.join(dir, "env", "cmdline"))).to be_falsey
      end.and_return(result)

      expect_galaxy_roles_fetched

      described_class.run(env_vars, extra_vars, playbook)
    end

    it "calls launch with expected tag" do
      expect(AwesomeSpawn).to receive(:run) do |command, options|
        expect(command).to eq("ansible-runner")
        expect(options[:env]).to match a_hash_including(env_vars)

        method, dir, json, args = options[:params]

        expect(method).to eq("run")
        expect(json).to   eq(:json)
        expect(args).to   eq(:ident => "result", :playbook => "playbook", :project_dir => "/path/to/my")

        hosts = File.read(File.join(dir, "inventory", "hosts"))
        expect(hosts).to eq("localhost")

        extravars = JSON.parse(File.read(File.join(dir, "env", "extravars")))
        expect(extravars).to eq("id" => uuid, "ansible_connection" => "local")

        cmdline = File.read(File.join(dir, "env", "cmdline"))
        expect(cmdline).to eq("--tags #{tags}")
      end.and_return(result)

      expect_galaxy_roles_fetched

      described_class.run(env_vars, extra_vars, playbook, :tags => tags)
    end

    it "calls run with the correct verbosity (and triggers debug mode)" do
      expect(AwesomeSpawn).to receive(:run) do |command, options|
        expect(command).to eq("ansible-runner")

        _method, _dir, _json, args = options[:params]
        expect(args).to eq(:ident => "result", :playbook => "playbook", :project_dir => "/path/to/my", "-vvvvv" => nil)
      end.and_return(result)

      response = described_class.run(env_vars, extra_vars, playbook, :verbosity => 6)
      expect(response.debug).to eq(true)
    end

    it "calls run with become options" do
      expect(AwesomeSpawn).to receive(:run) do |command, options|
        expect(command).to eq("ansible-runner")

        _method, dir, _json, _args = options[:params]
        cmdline = File.read(File.join(dir, "env", "cmdline"))

        expect(cmdline).to eq("--become")
      end.and_return(result)

      described_class.run(env_vars, extra_vars, playbook, :become_enabled => true)
    end

    context "without runner_env stubbing" do
      before { clear_runner_env_cache }
      after  { clear_runner_env_cache }

      it "calls run with the correct runner environment" do
        # Undo stubbing of runner_env in this particular test
        expect(described_class).to receive(:runner_env).and_call_original

        expect(described_class).to receive(:venv_python_path).and_return(venv_python_path)
        expect(described_class).to receive(:venv_bin_path).and_return(venv_bin_path)
        stub_const("ENV", "PATH" => system_path)
        stub_ansible_raw

        expect(AwesomeSpawn).to receive(:run) do |command, options|
          expect(command).to eq("ansible-runner")
          expect(options[:env]).to include({
            "PYTHONPATH" => runner_python_path,
            "PATH"       => runner_path,
          })
        end.and_return(result)

        described_class.run(env_vars, extra_vars, playbook, :become_enabled => true)
      end
    end

    context "with special characters" do
      let(:env_vars)   { {"ENV1" => "pa$%w0rd!'"} }
      let(:extra_vars) { {"name" => "john's server"} }

      it "calls launch with expected arguments" do
        expect(AwesomeSpawn).to receive(:run) do |command, options|
          expect(command).to eq("ansible-runner")
          expect(options[:env]).to match a_hash_including(env_vars)

          method, dir, json, args = options[:params]

          expect(method).to eq("run")
          expect(json).to   eq(:json)
          expect(args).to   eq(:ident => "result", :playbook => "playbook", :project_dir => "/path/to/my")

          hosts = File.read(File.join(dir, "inventory", "hosts"))
          expect(hosts).to eq("localhost")

          extravars = JSON.parse(File.read(File.join(dir, "env", "extravars")))
          expect(extravars).to eq("name" => "john's server", "ansible_connection" => "local")
        end.and_return(result)

        expect_galaxy_roles_fetched

        described_class.run(env_vars, extra_vars, playbook)
      end
    end
  end

  describe ".run_async" do
    let(:playbook) { "/path/to/my/playbook" }
    before do
      allow(described_class).to receive(:python_path).and_return(python_path)

      allow(described_class).to receive(:wait_for).and_yield
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(playbook).and_return(true)
    end

    it "calls ansible-runner with start" do
      expect(AwesomeSpawn).to receive(:run) do |command, options|
        expect(command).to eq("ansible-runner")
        expect(options[:env]).to match a_hash_including(env_vars)

        method, dir, json, args = options[:params]

        expect(method).to eq("start")
        expect(json).to   eq(:json)
        expect(args).to   eq(:ident => "result", :playbook => "playbook", :project_dir => "/path/to/my")

        hosts = File.read(File.join(dir, "inventory", "hosts"))
        expect(hosts).to eq("localhost")

        extravars = JSON.parse(File.read(File.join(dir, "env", "extravars")))
        expect(extravars).to eq("id" => uuid, "ansible_connection" => "local")

        expect(File.exist?(File.join(dir, "env", "cmdline"))).to be_falsey
      end.and_return(result)

      expect_galaxy_roles_fetched

      runner_result = described_class.run_async(env_vars, extra_vars, playbook)
      expect(runner_result).kind_of?(Ansible::Runner::ResponseAsync)
    end
  end

  describe ".run_queue" do
    let(:playbook) { "/path/to/my/playbook" }
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
      allow(described_class).to receive(:python_path).and_return(python_path)

      allow(described_class).to receive(:wait_for).and_yield
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(role_path).and_return(true)
    end

    it "runs ansible-runner with the role" do
      expect(AwesomeSpawn).to receive(:run) do |command, options|
        expect(command).to eq("ansible-runner")
        expect(options[:env]).to match a_hash_including(env_vars)

        method, dir, json, args = options[:params]

        expect(method).to eq("run")
        expect(json).to   eq(:json)
        expect(args).to   eq(:ident => "result", :role => role_name, :roles_path => role_path, :role_skip_facts => nil)

        hosts = File.read(File.join(dir, "inventory", "hosts"))
        expect(hosts).to eq("localhost")

        extravars = JSON.parse(File.read(File.join(dir, "env", "extravars")))
        expect(extravars).to eq("id" => uuid, "ansible_connection" => "local")

        expect(File.exist?(File.join(dir, "env", "cmdline"))).to be_falsey
      end.and_return(result)

      described_class.run_role(env_vars, extra_vars, role_name, :roles_path => role_path)
    end

    it "runs ansible-runner with role and tag" do
      expect(AwesomeSpawn).to receive(:run) do |command, options|
        expect(command).to eq("ansible-runner")
        expect(options[:env]).to match a_hash_including(env_vars)

        method, dir, json, args = options[:params]

        expect(method).to eq("run")
        expect(json).to   eq(:json)
        expect(args).to   eq(:ident => "result", :role => role_name, :roles_path => role_path, :role_skip_facts => nil)

        hosts = File.read(File.join(dir, "inventory", "hosts"))
        expect(hosts).to eq("localhost")

        extravars = JSON.parse(File.read(File.join(dir, "env", "extravars")))
        expect(extravars).to eq("id" => uuid, "ansible_connection" => "local")

        cmdline = File.read(File.join(dir, "env", "cmdline"))
        expect(cmdline).to eq("--tags #{tags}")
      end.and_return(result)

      described_class.run_role(env_vars, extra_vars, role_name, :roles_path => role_path, :tags => tags)
    end
  end

  describe ".run_role_async" do
    let(:role_name) { "my-custom-role" }
    let(:role_path) { "/path/to/my/roles" }
    before do
      allow(described_class).to receive(:python_path).and_return(python_path)

      allow(described_class).to receive(:wait_for).and_yield
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(role_path).and_return(true)
    end

    it "runs ansible-runner with the role" do
      expect(AwesomeSpawn).to receive(:run) do |command, options|
        expect(command).to eq("ansible-runner")
        expect(options[:env]).to match a_hash_including(env_vars)

        method, dir, json, args = options[:params]

        expect(method).to eq("start")
        expect(json).to   eq(:json)
        expect(args).to   eq(:ident => "result", :role => role_name, :roles_path => role_path, :role_skip_facts => nil)

        hosts = File.read(File.join(dir, "inventory", "hosts"))
        expect(hosts).to eq("localhost")

        extravars = JSON.parse(File.read(File.join(dir, "env", "extravars")))
        expect(extravars).to eq("id" => uuid, "ansible_connection" => "local")

        expect(File.exist?(File.join(dir, "env", "cmdline"))).to be_falsey
      end.and_return(result)

      described_class.run_role_async(env_vars, extra_vars, role_name, :roles_path => role_path)
    end
  end

  describe ".run_role_queue" do
    let(:role_name) { "my-custom-role" }
    let(:role_path) { "/path/to/my/roles" }
    let(:zone)      { FactoryBot.create(:zone) }
    let(:user)      { FactoryBot.create(:user) }

    it "queues Ansible::Runner.run in the right zone" do
      queue_args = {:zone => zone.name}
      described_class.run_role_queue(env_vars, extra_vars, role_name, user.name, queue_args, :roles_path => role_path)

      expect(MiqQueue.count).to eq(1)
      expect(MiqQueue.first.zone).to eq(zone.name)
    end
  end

  describe "#runner_env" do
    before { clear_runner_env_cache }
    after  { clear_runner_env_cache }

    describe "PYTHONPATH" do
      it "with venv_python_path valid and ansible exists" do
        expect(described_class).to receive(:venv_python_path).and_return(venv_python_path)
        stub_ansible_raw

        expect(described_class.runner_env["PYTHONPATH"]).to eq(runner_python_path)
      end

      it "with venv_python_path valid and ansible missing" do
        expect(described_class).to receive(:venv_python_path).and_return(venv_python_path)
        stub_ansible_raw(ansible_exists: false)

        expect(described_class.runner_env["PYTHONPATH"]).to eq(venv_python_path)
      end

      it "with venv_python_path missing and ansible exists" do
        expect(described_class).to receive(:venv_python_path).and_return(nil)
        stub_ansible_raw

        expect(described_class.runner_env["PYTHONPATH"]).to eq(python_path)
      end

      it "with venv_python_path missing and ansible_python_version missing" do
        expect(described_class).to receive(:venv_python_path).and_return(nil)
        stub_ansible_raw(ansible_exists: false)

        expect(described_class.runner_env).to_not include("PYTHONPATH")
      end
    end

    describe "PATH" do
      it "with venv_bin_path valid and PATH valid" do
        expect(described_class).to receive(:venv_bin_path).at_least(:once).and_return(venv_bin_path)
        stub_const("ENV", "PATH" => system_path)

        expect(described_class.runner_env["PATH"]).to eq(runner_path)
      end

      it "with venv_bin_path valid and PATH missing" do
        expect(described_class).to receive(:venv_bin_path).at_least(:once).and_return(venv_bin_path)
        stub_const("ENV", {})

        expect(described_class.runner_env["PATH"]).to eq(venv_bin_path)
      end

      it "with venv_bin_path missing and PATH valid" do
        expect(described_class).to receive(:venv_bin_path).at_least(:once).and_return(nil)
        stub_const("ENV", "PATH" => system_path)

        expect(described_class.runner_env["PATH"]).to eq(system_path)
      end

      it "with venv_bin_path missing and PATH missing" do
        expect(described_class).to receive(:venv_bin_path).at_least(:once).and_return(nil)
        stub_const("ENV", {})

        expect(described_class.runner_env).to_not include("PATH")
      end
    end
  end

  describe ".ansible_python_path (private)" do
    it "with ansible_version_raw valid" do
      expect(described_class).to receive(:ansible_version_raw).and_return(ansible_version_raw)
      expect(described_class).to receive(:`).with(a_string_including("python3.12 -c")).and_return(python_path)

      expect(described_class.send(:ansible_python_path)).to eq(python_path)
    end

    it "with ansible_version_raw missing" do
      expect(described_class).to receive(:ansible_version_raw).and_return("")
      expect(described_class).to_not receive(:`)

      expect(described_class.send(:ansible_python_path)).to eq(nil)
    end

    it "with ansible_python_version hacked" do
      expect(described_class).to receive(:ansible_python_version).and_return("-hacked")
      expect(described_class).to_not receive(:`).with(a_string_including("python-hacked -c"))

      expect { described_class.send(:ansible_python_path) }.to raise_error(RuntimeError, "python version is not a number: -hacked")
    end
  end

  describe ".ansible_python_version (private)" do
    it "when ansible is installed" do
      expect(described_class).to receive(:`).with(a_string_including("ansible --version")).and_return(ansible_version_raw)

      expect(described_class.send(:ansible_python_version)).to eq("3.12")
    end

    it "when ansible is not installed" do
      expect(described_class).to receive(:`).with(a_string_including("ansible --version")).and_return("")

      expect(described_class.send(:ansible_python_version)).to be_nil
    end
  end

  def expect_galaxy_roles_fetched
    content_double = instance_double(Ansible::Content)
    expect(Ansible::Content).to receive(:new).with("/path/to/my").and_return(content_double)
    expect(content_double).to receive(:fetch_galaxy_roles)
  end

  def stub_ansible_raw(ansible_exists: true)
    if ansible_exists
      expect(described_class).to receive(:ansible_version_raw).and_return(ansible_version_raw)
      expect(described_class).to receive(:python_path_raw).and_return(python_path)
    else
      expect(described_class).to receive(:ansible_version_raw).and_return("")
    end
  end

  def clear_runner_env_cache
    begin; described_class.remove_instance_variable(:@runner_env); rescue NameError; end
    begin; described_class.remove_instance_variable(:@venv_python_path); rescue NameError; end
    begin; described_class.remove_instance_variable(:@venv_bin_path); rescue NameError; end
  end
end
