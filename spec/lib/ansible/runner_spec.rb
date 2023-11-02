RSpec.describe Ansible::Runner do
  let(:uuid)       { "201ac780-7bf4-0136-3b9e-54e1ad8b3cf4" }
  let(:env_vars)   { {"ENV1" => "VAL1", "ENV2" => "VAL2"} }
  let(:extra_vars) { {"id" => uuid} }
  let(:tags)       { "tag" }
  let(:result)     { AwesomeSpawn::CommandResult.new("ansible-runner", "output", "", 100, "0") }

  let(:manageiq_venv_path)  { "/var/lib/manageiq/venv/python3.8/site-packages" }
  let(:ansible_python_path) { "/usr/local/lib64/python3.8/site-packages:/usr/local/lib/python3.8/site-packages:/usr/lib64/python3.8/site-packages:/usr/lib/python3.8/site-packages" }

  describe ".available?" do
    before { begin; described_class.remove_instance_variable(:@available); rescue NameError; end }
    after  { begin; described_class.remove_instance_variable(:@available); rescue NameError; end }

    it "when available" do
      expect(described_class).to receive(:system).with(/^which ansible-runner/).and_return(true)

      expect(described_class.available?).to be true
    end

    it "when not available" do
      expect(described_class).to receive(:system).with(/^which ansible-runner/).and_return(false)

      expect(described_class.available?).to be false
    end
  end

  describe ".run" do
    let(:playbook) { "/path/to/my/playbook" }
    before do
      allow(described_class).to receive(:python_path).and_return(ansible_python_path)

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

    context "without PYTHON_PATH stubbing" do
      before { described_class.instance_variable_set(:@python_path, nil) }
      after  { described_class.instance_variable_set(:@python_path, nil) }

      it "sets PYTHON_PATH correctly" do
        # Undo stubbing of python_path in this particular test
        expect(described_class).to receive(:python_path).and_call_original

        expect(described_class).to receive(:manageiq_venv_path).and_return(manageiq_venv_path)
        stub_ansible_raw(ansible_exists: true)

        expect(AwesomeSpawn).to receive(:run) do |command, options|
          expect(command).to eq("ansible-runner")

          expected_path = [manageiq_venv_path, ansible_python_path].join(File::PATH_SEPARATOR)
          expect(options[:env]["PYTHONPATH"]).to eq(expected_path)
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
      allow(described_class).to receive(:python_path).and_return(ansible_python_path)

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
      allow(described_class).to receive(:python_path).and_return(ansible_python_path)

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
      allow(described_class).to receive(:python_path).and_return(ansible_python_path)

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

  describe ".python_path (private)" do
    before { described_class.instance_variable_set(:@python_path, nil) }
    after  { described_class.instance_variable_set(:@python_path, nil) }

    it "with manageiq_venv_path valid and ansible_python_version valid" do
      expect(described_class).to receive(:manageiq_venv_path).and_return(manageiq_venv_path)
      stub_ansible_raw(ansible_exists: true)

      expect(described_class.send(:python_path)).to eq([manageiq_venv_path, ansible_python_path].join(File::PATH_SEPARATOR))
    end

    it "with manageiq_venv_path valid and ansible_python_version nil" do
      expect(described_class).to receive(:manageiq_venv_path).and_return(manageiq_venv_path)
      stub_ansible_raw(ansible_exists: false)

      expect(described_class.send(:python_path)).to eq(manageiq_venv_path)
    end

    it "with manageiq_venv_path nil and ansible_python_version valid" do
      expect(described_class).to receive(:manageiq_venv_path).and_return(nil)
      stub_ansible_raw(ansible_exists: true)

      expect(described_class.send(:python_path)).to eq(ansible_python_path)
    end

    it "with manageiq_venv_path nil and ansible_python_version nil" do
      expect(described_class).to receive(:manageiq_venv_path).and_return(nil)
      stub_ansible_raw(ansible_exists: false)

      expect(described_class.send(:python_path)).to eq("")
    end
  end

  describe ".ansible_python_paths (private)" do
    it "with ansible_python_version valid" do
      expect(described_class).to receive(:ansible_python_version).and_return("3.8")
      expect(described_class).to receive(:`).with(a_string_including("python3.8 -c")).and_return(ansible_python_path)

      expect(described_class.send(:ansible_python_paths)).to eq(
        [
          "/usr/local/lib64/python3.8/site-packages",
          "/usr/local/lib/python3.8/site-packages",
          "/usr/lib64/python3.8/site-packages",
          "/usr/lib/python3.8/site-packages"
        ]
      )
    end

    it "with ansible_python_version nil" do
      expect(described_class).to receive(:ansible_python_version).and_return(nil)
      expect(described_class).to_not receive(:`).with(a_string_including("python3.8 -c"))

      expect(described_class.send(:ansible_python_paths)).to eq([])
    end

    it "with ansible_python_version hacked" do
      expect(described_class).to receive(:ansible_python_version).and_return("-hacked")
      expect(described_class).to_not receive(:`).with(a_string_including("python-hacked -c"))

      expect { described_class.send(:ansible_python_paths) }.to raise_error(RuntimeError, "ansible python version is not a number: -hacked")
    end
  end

  describe ".ansible_python_version (private)" do
    it "with ansible using python 3.8" do
      expect(described_class).to receive(:`).with(a_string_including("ansible --version")).and_return(<<~EOF)
        ansible [core 2.12.7]
          config file = /etc/ansible/ansible.cfg
          configured module search path = ['/root/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
          ansible python module location = /usr/lib/python3.8/site-packages/ansible
          ansible collection location = /root/.ansible/collections:/usr/share/ansible/collections
          executable location = /usr/bin/ansible
          python version = 3.8.13 (default, Jun 24 2022, 15:27:57) [GCC 8.5.0 20210514 (Red Hat 8.5.0-13)]
          jinja version = 2.11.3
          libyaml = True
      EOF

      expect(described_class.send(:ansible_python_version)).to eq("3.8")
    end

    it "with ansible using python 3.9" do
      expect(described_class).to receive(:`).with(a_string_including("ansible --version")).and_return(<<~EOF)
        ansible [core 2.13.4]
          config file = None
          configured module search path = ['/Users/root/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
          ansible python module location = /usr/local/lib/python3.9/site-packages/ansible
          ansible collection location = /Users/root/.ansible/collections:/usr/share/ansible/collections
          executable location = /usr/local/bin/ansible
          python version = 3.9.13 (main, Aug  7 2022, 01:33:23) [Clang 13.1.6 (clang-1316.0.21.2.5)]
          jinja version = 3.1.2
          libyaml = True
      EOF

      expect(described_class.send(:ansible_python_version)).to eq("3.9")
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
      expect(described_class).to receive(:ansible_python_version_raw).and_return(<<~EOF)
        ansible [core 2.12.7]
          config file = /etc/ansible/ansible.cfg
          configured module search path = ['/root/.ansible/plugins/modules', '/usr/share/ansible/plugins/modules']
          ansible python module location = /usr/lib/python3.8/site-packages/ansible
          ansible collection location = /root/.ansible/collections:/usr/share/ansible/collections
          executable location = /usr/bin/ansible
          python version = 3.8.13 (default, Jun 24 2022, 15:27:57) [GCC 8.5.0 20210514 (Red Hat 8.5.0-13)]
          jinja version = 2.11.3
          libyaml = True
      EOF
      expect(described_class).to receive(:ansible_python_paths_raw).and_return(ansible_python_path)
    else
      expect(described_class).to receive(:ansible_python_version_raw).and_return("")
    end
  end
end
