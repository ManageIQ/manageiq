module Ansible
  class Runner
    class << self
      # Runs a playbook via ansible-runner, see: https://ansible-runner.readthedocs.io/en/latest/standalone.html#running-playbooks
      #
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        ansible-runner run
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @param playbook_path [String] Path to the playbook we will want to run
      # @param hosts [Array] List of hostnames to target with the playbook
      # @param credentials [Array] List of Authentication object ids to provide to the playbook run
      # @param verbosity [Integer] ansible-runner verbosity level 0-5
      # @return [Ansible::Runner::ResponseAsync] Response object that we can query for .running?, providing us the
      #         Ansible::Runner::Response object, when the job is finished.
      def run_async(env_vars, extra_vars, playbook_path, hosts: ["localhost"], credentials: [], verbosity: 0, become_enabled: false)
        run_via_cli(hosts,
                    credentials,
                    env_vars,
                    extra_vars,
                    :ansible_runner_method => "start",
                    :playbook              => playbook_path,
                    :verbosity             => verbosity,
                    :become_enabled        => become_enabled)
      end

      # Runs a role directly via ansible-runner, a simple playbook is then automatically created,
      # see: https://ansible-runner.readthedocs.io/en/latest/standalone.html#running-roles-directly
      #
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        ansible-runner run
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @param role_name [String] Ansible role name
      # @param roles_path [String] Path to the directory with roles
      # @param role_skip_facts [Boolean] Whether we should skip facts gathering, equals to 'gather_facts: False' in a
      #        playbook. True by default.
      # @param hosts [Array] List of hostnames to target with the role
      # @param credentials [Array] List of Authentication object ids to provide to the role run
      # @param verbosity [Integer] ansible-runner verbosity level 0-5
      # @return [Ansible::Runner::ResponseAsync] Response object that we can query for .running?, providing us the
      #         Ansible::Runner::Response object, when the job is finished.
      def run_role_async(env_vars, extra_vars, role_name, roles_path:, role_skip_facts: true, hosts: ["localhost"], credentials: [], verbosity: 0, become_enabled: false)
        run_via_cli(hosts,
                    credentials,
                    env_vars,
                    extra_vars,
                    :ansible_runner_method => "start",
                    :role                  => role_name,
                    :roles_path            => roles_path,
                    :role_skip_facts       => role_skip_facts,
                    :verbosity             => verbosity,
                    :become_enabled        => become_enabled)
      end

      # Runs a playbook via ansible-runner, see: https://ansible-runner.readthedocs.io/en/latest/standalone.html#running-playbooks
      #
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        ansible-runner run
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @param playbook_path [String] Path to the playbook we will want to run
      # @param tags [Hash] Hash with key/values pairs that will be passed as tags to the ansible-runner run
      # @param hosts [Array] List of hostnames to target with the playbook
      # @param credentials [Array] List of Authentication object ids to provide to the playbook run
      # @param verbosity [Integer] ansible-runner verbosity level 0-5
      # @return [Ansible::Runner::Response] Response object with all details about the ansible run
      def run(env_vars, extra_vars, playbook_path, tags: nil, hosts: ["localhost"], credentials: [], verbosity: 0, become_enabled: false)
        run_via_cli(hosts,
                    credentials,
                    env_vars,
                    extra_vars,
                    :tags           => tags,
                    :playbook       => playbook_path,
                    :verbosity      => verbosity,
                    :become_enabled => become_enabled)
      end

      # Runs a role directly via ansible-runner, a simple playbook is then automatically created,
      # see: https://ansible-runner.readthedocs.io/en/latest/standalone.html#running-roles-directly
      #
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        ansible-runner run
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @param role_name [String] Ansible role name
      # @param roles_path [String] Path to the directory with roles
      # @param role_skip_facts [Boolean] Whether we should skip facts gathering, equals to 'gather_facts: False' in a
      #        playbook. True by default.
      # @param tags [Hash] Hash with key/values pairs that will be passed as tags to the ansible-runner run
      # @param hosts [Array] List of hostnames to target with the role
      # @param credentials [Array] List of Authentication object ids to provide to the role run
      # @param verbosity [Integer] ansible-runner verbosity level 0-5
      # @return [Ansible::Runner::Response] Response object with all details about the ansible run
      def run_role(env_vars, extra_vars, role_name, roles_path:, role_skip_facts: true, tags: nil, hosts: ["localhost"], credentials: [], verbosity: 0, become_enabled: false)
        run_via_cli(hosts,
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
      # @param playbook_path [String] Path to the playbook we will want to run
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
      # @param roles_path [String] Path to the directory with roles
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

      # Runs a playbook or a role via ansible-runner.
      #
      # @param hosts [Array] List of hostnames to target
      # @param credentials [Array] List of Authentication object ids to provide to the run
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        ansible-runner run
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @param tags [Hash] Hash with key/values pairs that will be passed as tags to the ansible-runner run
      # @param ansible_runner_method [String] Optional method we will use to run the ansible-runner. It can be either
      #        "run", which is sync call, or "start" which is async call.  Default is "run"
      # @param verbosity [Integer] ansible-runner verbosity level 0-5
      # @param playbook_or_role_args [Hash] Hash that includes the :playbook key or :role keys
      # @return [Ansible::Runner::Response] Response object with all details about the ansible run
      def run_via_cli(hosts, credentials, env_vars, extra_vars, tags: nil, ansible_runner_method: "run", verbosity: 0, become_enabled: false, **playbook_or_role_args)
        # If we are running against only localhost and no other value is set for ansible_connection
        # then assume we don't want to ssh locally
        extra_vars["ansible_connection"] ||= "local" if hosts == ["localhost"]

        validate_params!(env_vars, extra_vars, tags, ansible_runner_method, playbook_or_role_args)

        base_dir = Dir.mktmpdir("ansible-runner")

        cred_command_line, cred_env_vars, cred_extra_vars = credentials_info(credentials, base_dir)

        command_line_hash = tags.present? ? {:tags => tags} : {}
        if become_enabled
          command_line_hash[:become] = nil
        end
        command_line_hash.merge!(cred_command_line)

        env_vars_hash   = env_vars.merge(cred_env_vars).merge(python_env)
        extra_vars_hash = extra_vars.merge(cred_extra_vars)

        create_hosts_file(base_dir, hosts)
        create_extra_vars_file(base_dir, extra_vars_hash)
        create_cmdline_file(base_dir, command_line_hash)

        params = runner_params(base_dir, ansible_runner_method, playbook_or_role_args, verbosity)

        begin
          fetch_galaxy_roles(playbook_or_role_args)

          result = wait_for(pid_file(base_dir)) do
            AwesomeSpawn.run("ansible-runner", :env => env_vars_hash, :params => params)
          end

          res = response(base_dir, ansible_runner_method, result)
        ensure
          # Clean up the tmp dir for the sync method, for async we will clean it up after the job is finished and we've
          # read the output, that will be written into this directory.
          res&.cleanup_filesystem! unless async?(ansible_runner_method)
        end
      end

      # @param base_dir [String] ansible-runner private_data_dir parameter
      # @param ansible_runner_method [String] Method we will use to run the ansible-runner. It can be either "run",
      #        which is sync call, or "start" which is async call
      # @param result [AwesomeSpawn::CommandResult] Result object of AwesomeSpawn.run
      # @return [Ansible::Runner::ResponseAsync, Ansible::Runner::Response] response or ResponseAsync based on the
      #         ansible_runner_method
      def response(base_dir, ansible_runner_method, result)
        if async?(ansible_runner_method)
          Ansible::Runner::ResponseAsync.new(:base_dir => base_dir)
        else
          Ansible::Runner::Response.new(:base_dir => base_dir,
                                        :stdout   => result.output,
                                        :stderr   => result.error)
        end
      end

      # @return [Boolean] True if ansible-runner will run on background
      def async?(ansible_runner_method)
        ansible_runner_method == "start"
      end

      def runner_params(base_dir, ansible_runner_method, playbook_or_role_args, verbosity)
        runner_args = playbook_or_role_args.dup

        runner_args.delete(:roles_path) if runner_args[:roles_path].nil?

        runner_args[:role_skip_facts] = nil if runner_args.delete(:role_skip_facts)
        runner_args[:ident] = "result"

        playbook = runner_args.delete(:playbook)
        if playbook
          runner_args[:playbook]    = File.basename(playbook)
          runner_args[:project_dir] = File.dirname(playbook)
        end

        if verbosity.to_i > 0
          v_flag = "-#{"v" * verbosity.to_i.clamp(1, 5)}"
          runner_args[v_flag] = nil
        end

        [ansible_runner_method, base_dir, :json, runner_args]
      end

      # Asserts passed parameters are correct, if not throws an exception.
      def validate_params!(env_vars, extra_vars, tags, ansible_runner_method, playbook_or_role_args)
        errors = []

        errors << "env_vars must be a Hash, got: #{hash.class}" unless env_vars.kind_of?(Hash)
        errors << "extra_vars must be a Hash, got: #{hash.class}" unless extra_vars.kind_of?(Hash)
        errors << "tags must be a String, got: #{tags.class}" if tags.present? && !tags.kind_of?(String)

        unless %w[run start].include?(ansible_runner_method.to_s)
          errors << "ansible_runner_method must be 'run' or 'start'"
        end

        unless playbook_or_role_args.keys == %i[playbook] || playbook_or_role_args.keys.sort == %i[role role_skip_facts roles_path]
          errors << "Unexpected playbook/role args: #{playbook_or_role_args}"
        end

        playbook = playbook_or_role_args[:playbook]
        errors << "playbook path doesn't exist: #{playbook}" if playbook && !File.exist?(playbook)
        roles_path = playbook_or_role_args[:roles_path]
        errors << "roles path doesn't exist: #{roles_path}" if roles_path && !File.exist?(roles_path)

        raise ArgumentError, errors.join("; ") if errors.any?
      end

      def fetch_galaxy_roles(playbook_or_role_args)
        return unless playbook_or_role_args[:playbook]

        playbook_dir = File.dirname(playbook_or_role_args[:playbook])
        Ansible::Content.new(playbook_dir).fetch_galaxy_roles
      end

      def python_env
        if python3_modules_path.present?
          { "PYTHONPATH" => python3_modules_path }
        elsif python2_modules_path.present?
          { "PYTHONPATH" => python2_modules_path }
        else
          {}
        end
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

      def env_dir(base_dir)
        FileUtils.mkdir_p(File.join(base_dir, "env")).first
      end

      def pid_file(base_dir)
        File.join(base_dir, "pid")
      end

      def wait_for(path, timeout: 10.seconds)
        require "listen"
        require "concurrent"

        path_created = Concurrent::Event.new

        listener = Listen.to(File.dirname(path), :only => %r{\A#{File.basename(path)}\z}) do |modified, added, _removed|
          path_created.set if added.include?(path) || modified.include?(path)
        end

        thread = Thread.new { listener.start }

        begin
          res = yield
          raise "Timed out waiting for #{path}" unless path_created.wait(timeout)
        ensure
          listener.stop
          thread.join
        end

        res
      end

      PYTHON2_MODULE_PATHS = %w[
        /var/lib/manageiq/venv/lib/python2.7/site-packages
      ].freeze
      def python2_modules_path
        @python2_modules_path ||= begin
          determine_existing_python_paths_for(*PYTHON2_MODULE_PATHS).join(File::PATH_SEPARATOR)
        end
      end

      PYTHON3_MODULE_PATHS = %w[
        /usr/lib64/python3.6/site-packages
        /var/lib/awx/venv/ansible/lib/python3.6/site-packages
        /var/lib/manageiq/venv/lib/python3.6/site-packages
      ].freeze
      def python3_modules_path
        @python3_modules_path ||= begin
          determine_existing_python_paths_for(*PYTHON3_MODULE_PATHS).join(File::PATH_SEPARATOR)
        end
      end

      def determine_existing_python_paths_for(*paths)
        paths.select { |path| File.exist?(path) }
      end
    end
  end
end
