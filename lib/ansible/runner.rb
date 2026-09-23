module Ansible
  class Runner
    class << self
      # @return [Boolean] True if the Ansible EE image is configured and the
      #         underlying container runtime is available on this host.
      def available?
        Settings.embedded_ansible.execution_environment_image.present? &&
          container_runner_class.present?
      end

      # Runs a playbook via the Ansible Execution Environment container.
      # See: https://ansible-runner.readthedocs.io/en/latest/standalone.html#running-playbooks
      #
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        ansible-runner run
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @param playbook_path [String] Absolute path to the playbook file on the host
      # @param hosts [Array] List of hostnames to target with the playbook
      # @param credentials [Array] List of Authentication object ids to provide to the playbook run
      # @param verbosity [Integer] ansible-runner verbosity level 0-5
      # @return [Ansible::Runner::ResponseAsync] Response object that we can query for .running?, providing us the
      #         Ansible::Runner::Response object, when the job is finished.
      def run_async(env_vars, extra_vars, playbook_path, hosts: ["localhost"], credentials: [], verbosity: 0, become_enabled: false)
        run_via_container(hosts,
                          credentials,
                          env_vars,
                          extra_vars,
                          :async          => true,
                          :playbook       => playbook_path,
                          :verbosity      => verbosity,
                          :become_enabled => become_enabled)
      end

      # Runs a role directly via the Ansible Execution Environment container.
      # See: https://ansible-runner.readthedocs.io/en/latest/standalone.html#running-roles-directly
      #
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        ansible-runner run
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @param role_name [String] Ansible role name
      # @param roles_path [String] Absolute path to the directory containing the role on the host
      # @param role_skip_facts [Boolean] Whether we should skip facts gathering, equals to 'gather_facts: False' in a
      #        playbook. True by default.
      # @param hosts [Array] List of hostnames to target with the role
      # @param credentials [Array] List of Authentication object ids to provide to the role run
      # @param verbosity [Integer] ansible-runner verbosity level 0-5
      # @return [Ansible::Runner::ResponseAsync] Response object that we can query for .running?, providing us the
      #         Ansible::Runner::Response object, when the job is finished.
      def run_role_async(env_vars, extra_vars, role_name, roles_path:, role_skip_facts: true, hosts: ["localhost"], credentials: [], verbosity: 0, become_enabled: false)
        run_via_container(hosts,
                          credentials,
                          env_vars,
                          extra_vars,
                          :async           => true,
                          :role            => role_name,
                          :roles_path      => roles_path,
                          :role_skip_facts => role_skip_facts,
                          :verbosity       => verbosity,
                          :become_enabled  => become_enabled)
      end

      # Runs a playbook via the Ansible Execution Environment container.
      # See: https://ansible-runner.readthedocs.io/en/latest/standalone.html#running-playbooks
      #
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        ansible-runner run
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @param playbook_path [String] Absolute path to the playbook file on the host
      # @param tags [Hash] Hash with key/values pairs that will be passed as tags to the ansible-runner run
      # @param hosts [Array] List of hostnames to target with the playbook
      # @param credentials [Array] List of Authentication object ids to provide to the playbook run
      # @param verbosity [Integer] ansible-runner verbosity level 0-5
      # @return [Ansible::Runner::Response] Response object with all details about the ansible run
      def run(env_vars, extra_vars, playbook_path, tags: nil, hosts: ["localhost"], credentials: [], verbosity: 0, become_enabled: false)
        run_via_container(hosts,
                          credentials,
                          env_vars,
                          extra_vars,
                          :tags           => tags,
                          :playbook       => playbook_path,
                          :verbosity      => verbosity,
                          :become_enabled => become_enabled)
      end

      # Runs a role directly via the Ansible Execution Environment container.
      # See: https://ansible-runner.readthedocs.io/en/latest/standalone.html#running-roles-directly
      #
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        ansible-runner run
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @param role_name [String] Ansible role name
      # @param roles_path [String] Absolute path to the directory containing the role on the host
      # @param role_skip_facts [Boolean] Whether we should skip facts gathering, equals to 'gather_facts: False' in a
      #        playbook. True by default.
      # @param tags [Hash] Hash with key/values pairs that will be passed as tags to the ansible-runner run
      # @param hosts [Array] List of hostnames to target with the role
      # @param credentials [Array] List of Authentication object ids to provide to the role run
      # @param verbosity [Integer] ansible-runner verbosity level 0-5
      # @return [Ansible::Runner::Response] Response object with all details about the ansible run
      def run_role(env_vars, extra_vars, role_name, roles_path:, role_skip_facts: true, tags: nil, hosts: ["localhost"], credentials: [], verbosity: 0, become_enabled: false)
        run_via_container(hosts,
                          credentials,
                          env_vars,
                          extra_vars,
                          :tags            => tags,
                          :role            => role_name,
                          :roles_path      => roles_path,
                          :role_skip_facts => role_skip_facts,
                          :verbosity       => verbosity,
                          :become_enabled  => become_enabled)
      end

      # Runs "run" method via queue
      #
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        ansible-runner run
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @param playbook_path [String] Absolute path to the playbook file on the host
      # @param user_id [String] Current user identifier
      # @param queue_opts [Hash] Additional options that will be passed to MiqQueue record creation
      # @param hosts [Array] List of hostnames to target with the playbook
      # @param credentials [Array] List of Authentication object ids to provide to the playbook run
      # @param verbosity [Integer] ansible-runner verbosity level 0-5
      # @return [BigInt] ID of MiqTask record wrapping the task
      def run_queue(env_vars, extra_vars, playbook_path, user_id, queue_opts, hosts: ["localhost"], credentials: [], verbosity: 0, become_enabled: false)
        kwargs = {
          :hosts          => hosts,
          :credentials    => credentials,
          :verbosity      => verbosity,
          :become_enabled => become_enabled
        }
        run_in_queue("run", user_id, queue_opts, [env_vars, extra_vars, playbook_path, kwargs])
      end

      # Runs "run_role" method via queue
      #
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        ansible-runner run
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @param role_name [String] Ansible role name
      # @param user_id [String] Current user identifier
      # @param queue_opts [Hash] Additional options that will be passed to MiqQueue record creation
      # @param roles_path [String] Absolute path to the directory containing the role on the host
      # @param role_skip_facts [Boolean] Whether we should skip facts gathering, equals to 'gather_facts: False' in a
      #        playbook. True by default.
      # @param hosts [Array] List of hostnames to target with the role
      # @param credentials [Array] List of Authentication object ids to provide to the role run
      # @param verbosity [Integer] ansible-runner verbosity level 0-5
      # @return [BigInt] ID of MiqTask record wrapping the task
      def run_role_queue(env_vars, extra_vars, role_name, user_id, queue_opts, roles_path:, role_skip_facts: true, hosts: ["localhost"], credentials: [], verbosity: 0, become_enabled: false)
        kwargs = {
          :roles_path      => roles_path,
          :role_skip_facts => role_skip_facts,
          :hosts           => hosts,
          :credentials     => credentials,
          :verbosity       => verbosity,
          :become_enabled  => become_enabled
        }
        run_in_queue("run_role", user_id, queue_opts, [env_vars, extra_vars, role_name, kwargs])
      end

      private

      # Run a method on self class, via queue, executed by generic worker
      #
      # @param method_name [String] A public method name on self
      # @param user_id [String] Current user identifier
      # @param queue_opts [Hash] Additional options that will be passed to MiqQueue record creation
      # @param args [Array] Arguments that will be passed to the <method_name> method
      # @return [BigInt] ID of MiqTask record wrapping the task
      def run_in_queue(method_name, user_id, queue_opts, args)
        queue_opts = {
          :args        => args,
          :queue_name  => "generic",
          :class_name  => name,
          :method_name => method_name,
        }.merge(queue_opts)

        task_opts = {
          :action => "Run Ansible Playbook",
          :userid => user_id,
        }

        MiqTask.generic_action_with_callback(task_opts, queue_opts)
      end

      # Runs a playbook or role inside the Ansible Execution Environment container.
      #
      # @param hosts [Array] List of hostnames to target
      # @param credentials [Array] List of Authentication object ids to provide to the run
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        ansible-runner run
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @param tags [String] Comma-separated tag list to pass to ansible-runner
      # @param async [Boolean] Whether to run asynchronously. Default false.
      # @param verbosity [Integer] ansible-runner verbosity level 0-5
      # @param playbook_or_role_args [Hash] Hash that includes the :playbook key or :role keys
      # @return [Ansible::Runner::Response, Ansible::Runner::ResponseAsync]
      def run_via_container(hosts, credentials, env_vars, extra_vars, tags: nil, async: false, verbosity: 0, become_enabled: false, **playbook_or_role_args)
        extra_vars["ansible_connection"] ||= "local" if hosts == ["localhost"]

        validate_params!(env_vars, extra_vars, tags, playbook_or_role_args)

        base_dir = Pathname.new(Dir.mktmpdir("ansible-runner")).realpath
        debug    = verbosity.to_i >= 5 || env_vars["ANSIBLE_KEEP_REMOTE_FILES"]

        cred_command_line, cred_env_vars, cred_extra_vars = credentials_info(credentials, base_dir)

        command_line_hash = tags.present? ? {:tags => tags} : {}
        command_line_hash[:become] = nil if become_enabled
        command_line_hash.merge!(cred_command_line)

        env_vars_hash   = {"ANSIBLE_FORCE_COLOR" => "true"}.merge(env_vars).merge(cred_env_vars)
        extra_vars_hash = extra_vars.merge(cred_extra_vars)

        create_hosts_file(base_dir, hosts)
        create_extra_vars_file(base_dir, extra_vars_hash)
        create_cmdline_file(base_dir, command_line_hash)
        copy_content(base_dir, playbook_or_role_args)

        image   = Settings.embedded_ansible.execution_environment_image
        runner  = build_container_runner
        command = build_runner_cmd(base_dir, playbook_or_role_args, verbosity)
        volumes = [{:host_path => base_dir.to_s, :container_path => "/runner", :options => runner_volume_options}]

        # Build a minimal Floe context carrying only the execution ID needed by
        # the Docker/Podman runner for container labelling.
        require "floe"
        context = Floe::Workflow::Context.new
        context.prepare_start("ansible")

        runner_context = runner.run_async!(
          "docker://#{image}",
          env_vars_hash,
          {},
          context,
          :volumes => volumes,
          :command => command
        )

        response_async = Ansible::Runner::ResponseAsync.new(
          :runner_class   => runner.class,
          :runner_context => runner_context,
          :base_dir       => base_dir,
          :debug          => debug
        )

        async ? response_async : response_async.wait
      end

      # Asserts passed parameters are correct, if not throws an exception.
      def validate_params!(env_vars, extra_vars, tags, playbook_or_role_args)
        errors = []

        errors << "env_vars must be a Hash, got: #{env_vars.class}" unless env_vars.kind_of?(Hash)
        errors << "extra_vars must be a Hash, got: #{extra_vars.class}" unless extra_vars.kind_of?(Hash)
        errors << "tags must be a String, got: #{tags.class}" if tags.present? && !tags.kind_of?(String)

        unless playbook_or_role_args.keys == %i[playbook] || playbook_or_role_args.keys.sort == %i[role role_skip_facts roles_path]
          errors << "Unexpected playbook/role args: #{playbook_or_role_args}"
        end

        playbook = playbook_or_role_args[:playbook]
        errors << "playbook path doesn't exist: #{playbook}" if playbook && !File.exist?(playbook)
        roles_path = playbook_or_role_args[:roles_path]
        errors << "roles path doesn't exist: #{roles_path}" if roles_path && !File.exist?(roles_path)

        raise ArgumentError, errors.join("; ") if errors.any?
      end

      # Builds the ansible-runner command array to pass as CMD to the container.
      #
      # @param playbook_or_role_args [Hash] :playbook or :role/:roles_path/:role_skip_facts
      # @param verbosity [Integer] 0-5
      # @return [Array<String>]
      def build_runner_cmd(base_dir, playbook_or_role_args, verbosity)
        commands = []

        if playbook_or_role_args[:playbook]
          if File.exist?(File.join(base_dir, "project", "roles", "requirements.yml"))
            commands << AwesomeSpawn.build_command_line("ansible-galaxy", ["install", "-r", "/runner/project/roles/requirements.yml", "-p", "/runner/project/roles"])
          elsif File.exist?(File.join(base_dir, "project", "requirements.yml"))
            commands << AwesomeSpawn.build_command_line("ansible-galaxy", ["install", "-r", "/runner/project/requirements.yml", "-p", "/runner/project/roles"])
          end
        elsif playbook_or_role_args[:roles_path]
          if File.exist?(File.join(base_dir, "roles", "requirements.yml"))
            commands << AwesomeSpawn.build_command_line("ansible-galaxy", ["install", "-r", "/runner/roles/requirements.yml", "-p", "/runner/roles"])
          end
        end

        runner_args = ["ansible-runner", "run", "/runner", "--ident", "result", "--json"]

        if playbook_or_role_args[:playbook]
          runner_args += ["--playbook", File.basename(playbook_or_role_args[:playbook])]
        else
          runner_args += ["--role", playbook_or_role_args[:role],
                          "--roles-path", "/runner/roles"]
          runner_args << "--role-skip-facts" if playbook_or_role_args[:role_skip_facts]
        end

        if verbosity.to_i > 0
          runner_args << "-#{"v" * verbosity.to_i.clamp(1, 5)}"
        end

        commands << AwesomeSpawn.build_command_line(runner_args.first, runner_args[1..])

        ["sh", "-c", commands.join(" && ")]
      end

      # Resolves and memoizes the Floe container runner class for this deployment.
      #
      # @return [Class, nil]
      def container_runner_class
        @container_runner_class ||= begin
          require "floe"

          if MiqEnvironment::Command.is_podified?
            Floe::ContainerRunner::Kubernetes
          elsif MiqEnvironment::Command.is_appliance? || MiqEnvironment::Command.supports_command?("podman")
            Floe::ContainerRunner::Podman
          elsif MiqEnvironment::Command.supports_command?("docker")
            Floe::ContainerRunner::Docker
          end
        end
      end

      # Returns a new instance of the selected container runner.
      #
      # @return [Floe::Runner]
      def build_container_runner
        container_runner_class.new
      end

      # Returns the volume mount options string for the ansible-runner base_dir.
      #
      # @return [String]
      def runner_volume_options
        container_runner_class == Floe::ContainerRunner::Podman ? "z,U" : "z"
      end

      def credentials_info(credentials, base_dir)
        command_line = {}
        env_vars     = {}
        extra_vars   = {}
        credentials.each do |id|
          cred = Ansible::Runner::Credential.new(id, base_dir)

          command_line.merge!(cred.command_line)
          env_vars.merge!(cred.env_vars)
          extra_vars.merge!(cred.extra_vars)

          cred.write_config_files
        end

        [command_line, env_vars, extra_vars]
      end

      def create_hosts_file(dir, hosts)
        inventory_dir = File.join(dir, "inventory")
        hosts_file    = File.join(inventory_dir, "hosts")

        FileUtils.mkdir_p(inventory_dir)
        File.write(hosts_file, hosts.join("\n"))
      end

      def create_extra_vars_file(dir, extra_vars)
        return if extra_vars.blank?

        extra_vars_file = File.join(env_dir(dir), "extravars")
        File.write(extra_vars_file, extra_vars.to_json)
      end

      def create_cmdline_file(dir, cmd_line)
        return if cmd_line.blank?

        cmd_line_file = File.join(env_dir(dir), "cmdline")
        cmd_string    = AwesomeSpawn.build_command_line(nil, cmd_line).lstrip

        File.write(cmd_line_file, cmd_string)
      end

      # Copies playbook/role content into the ansible-runner private data directory so
      # the container can find it under /runner/project or /runner/roles.
      #
      # For a playbook run, the contents of the directory containing the playbook are
      # copied into base_dir/project/, preserving sibling files (vars files, roles/, etc.).
      #
      # For a role run, the roles_path directory is copied into base_dir/roles/.
      def copy_content(base_dir, playbook_or_role_args)
        if (playbook = playbook_or_role_args[:playbook])
          project_dir = FileUtils.mkdir_p(File.join(base_dir, "project")).first
          FileUtils.cp_r(Dir[File.join(File.dirname(playbook), "*")], project_dir)
        elsif (roles_path = playbook_or_role_args[:roles_path])
          FileUtils.cp_r(roles_path, File.join(base_dir, "roles"))
        end
      end

      def env_dir(base_dir)
        FileUtils.mkdir_p(File.join(base_dir, "env")).first
      end
    end
  end
end
