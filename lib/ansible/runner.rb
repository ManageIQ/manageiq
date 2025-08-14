module Ansible
  class Runner
    class << self
      def available?
        return @available if defined?(@available)

        @available = system(runner_env, "which ansible-runner >/dev/null 2>&1")
      end

      def runner_env
        @runner_env ||= {
          "PYTHONPATH" => [venv_python_path, ansible_python_path].compact.join(File::PATH_SEPARATOR),
          "PATH"       => [venv_bin_path, ENV["PATH"].presence].compact.join(File::PATH_SEPARATOR)
        }.delete_blanks
      end

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

        base_dir = Pathname.new(Dir.mktmpdir("ansible-runner")).realpath
        debug    = verbosity.to_i >= 5 || env_vars["ANSIBLE_KEEP_REMOTE_FILES"]

        cred_command_line, cred_env_vars, cred_extra_vars = credentials_info(credentials, base_dir)

        command_line_hash = tags.present? ? {:tags => tags} : {}
        if become_enabled
          command_line_hash[:become] = nil
        end
        command_line_hash.merge!(cred_command_line)

        env_vars_hash   = env_vars.merge(cred_env_vars).merge(runner_env)
        extra_vars_hash = extra_vars.merge(cred_extra_vars)

        create_hosts_file(base_dir, hosts)
        create_extra_vars_file(base_dir, extra_vars_hash)
        create_cmdline_file(base_dir, command_line_hash)

        params = runner_params(base_dir, ansible_runner_method, playbook_or_role_args, verbosity)

        # puts "#{env_vars_hash.map { |k, v| "#{k}=#{v}" }.join(" ")} #{AwesomeSpawn.build_command_line("ansible-runner", params)}"

        begin
          fetch_galaxy_roles(playbook_or_role_args)

          result = if async?(ansible_runner_method)
                     wait_for(base_dir, "pid") { AwesomeSpawn.run("ansible-runner", :env => env_vars_hash, :params => params) }
                   else
                     AwesomeSpawn.run("ansible-runner", :env => env_vars_hash, :params => params)
                   end

          res = response(base_dir, ansible_runner_method, result, debug)
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
      def response(base_dir, ansible_runner_method, result, debug)
        if async?(ansible_runner_method)
          Ansible::Runner::ResponseAsync.new(
            :base_dir     => base_dir,
            :command_line => result.command_line,
            :debug        => debug
          )
        else
          Ansible::Runner::Response.new(
            :base_dir     => base_dir,
            :command_line => result.command_line,
            :stdout       => result.output,
            :stderr       => result.error,
            :debug        => debug
          )
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
        Ansible::Content.new(playbook_dir).fetch_galaxy_roles(runner_env)
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

      def wait_for(base_dir, target_path, timeout: 10.seconds)
        require "listen"
        require "concurrent"

        path_created = Concurrent::Event.new

        listener = Listen.to(base_dir, :only => %r{\A#{target_path}\z}) do |modified, added, _removed|
          path_created.set if added.include?(base_dir.join(target_path).to_s) || modified.include?(base_dir.join(target_path).to_s)
        end
        listener.start
        wait_for_listener_start(listener)

        begin
          res = yield
          raise "Timed out waiting for #{target_path}" unless path_created.wait(timeout)
        ensure
          listener.stop
        end

        res
      end

      # The listen gem creates an internal thread, @run_thread, which on most target systems
      # is where the actually listening is done. However, on macOS, @run_thread creates a
      # second thread, @worker_thread, which does the actual listening. It's possible that
      # although the listener is started, the @worker_thread hasn't actually started yet.
      # This leaves a window where the target_path we are waiting on can actually be created
      # before the @worker_thread is started and we "miss" the creation of the target_path.
      # This method ensures that we won't move on until that thread is ready, further ensuring
      # we can't miss the creation of the target_path.
      def wait_for_listener_start(listener)
        if RbConfig::CONFIG['host_os'].include?("darwin")
          listener_adapter = listener.instance_variable_get(:@backend).instance_variable_get(:@adapter)
          until listener_adapter.instance_variable_get(:@worker_thread)&.alive?
            sleep(0.01) # yield to other threads to allow them to start
          end
        end
      end

      VENV_ROOT = "/var/lib/manageiq/venv".freeze

      def venv_python_path
        return @venv_python_path if defined?(@venv_python_path)

        @venv_python_path = Dir.glob(File.join(VENV_ROOT, "lib/python#{ansible_python_version}/site-packages")).first
      end

      def venv_bin_path
        return @venv_bin_path if defined?(@venv_bin_path)

        @venv_bin_path = Dir.glob(File.join(VENV_ROOT, "bin")).first
      end

      def ansible_python_path
        python_path_raw(ansible_python_version).presence
      end

      def ansible_python_version
        ansible_version_raw.match(/python version = (\d+\.\d+)\./)&.captures&.first
      end

      # NOTE: This method is ignored by brakeman in the config/brakeman.ignore
      def python_path_raw(version)
        return "" if version.blank?

        # This check allows us to ignore the brakeman warning about command line injection
        raise "python version is not a number: #{version}" unless version.match?(/^\d+\.\d+$/)

        `python#{version} -c 'import site; print(":".join(site.getsitepackages()))'`.chomp
      end

      # NOTE: This method is ignored by brakeman in the config/brakeman.ignore
      def ansible_version_raw
        ansible = venv_bin_path ? File.join(venv_bin_path, "ansible") : "ansible"
        `#{ansible} --version 2>/dev/null`.chomp
      end
    end
  end
end
