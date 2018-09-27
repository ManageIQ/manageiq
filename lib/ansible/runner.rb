module Ansible
  class Runner
    class << self
      # Runs a playbook via ansible-runner, see: https://ansible-runner.readthedocs.io/en/latest/standalone.html#running-playbooks
      #
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        ansible-runner run
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @param playbook_path [String] Path to the playbook we will want to run
      # @return [Ansible::Runner::ResponseAsync] Response object that we can query for .running?, providing us the
      #         Ansible::Runner::Response object, when the job is finished.
      def run_async(env_vars, extra_vars, playbook_path)
        run_via_cli(env_vars,
                    extra_vars,
                    :ansible_runner_method => "start",
                    :playbook              => playbook_path)
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
      # @return [Ansible::Runner::ResponseAsync] Response object that we can query for .running?, providing us the
      #         Ansible::Runner::Response object, when the job is finished.
      def run_role_async(env_vars, extra_vars, role_name, roles_path:, role_skip_facts: true)
        run_via_cli(env_vars,
                    extra_vars,
                    :ansible_runner_method => "start",
                    :role                  => role_name,
                    :roles_path            => roles_path,
                    :role_skip_facts       => role_skip_facts)
      end

      # Runs a playbook via ansible-runner, see: https://ansible-runner.readthedocs.io/en/latest/standalone.html#running-playbooks
      #
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        ansible-runner run
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @param tags [Hash] Hash with key/values pairs that will be passed as tags to the ansible-runner run
      # @param playbook_path [String] Path to the playbook we will want to run
      # @return [Ansible::Runner::Response] Response object with all details about the ansible run
      def run(env_vars, extra_vars, playbook_path, tags: nil)
        run_via_cli(env_vars,
                    extra_vars,
                    :tags     => tags,
                    :playbook => playbook_path)
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
      # @return [Ansible::Runner::Response] Response object with all details about the ansible run
      def run_role(env_vars, extra_vars, role_name, roles_path:, role_skip_facts: true, tags: nil)
        run_via_cli(env_vars,
                    extra_vars,
                    :tags            => tags,
                    :role            => role_name,
                    :roles_path      => roles_path,
                    :role_skip_facts => role_skip_facts,)
      end

      # Runs "run" method via queue
      #
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        ansible-runner run
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @param playbook_path [String] Path to the playbook we will want to run
      # @param user_id [String] Current user identifier
      # @param queue_opts [Hash] Additional options that will be passed to MiqQueue record creation
      # @return [BigInt] ID of MiqTask record wrapping the task
      def run_queue(env_vars, extra_vars, playbook_path, user_id, queue_opts)
        run_in_queue("run", user_id, queue_opts, [env_vars, extra_vars, playbook_path])
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
      # @return [BigInt] ID of MiqTask record wrapping the task
      def run_role_queue(env_vars, extra_vars, role_name, user_id, queue_opts, roles_path:, role_skip_facts: true)
        run_in_queue("run_role", user_id, queue_opts,
                     [env_vars, extra_vars, role_name, {:roles_path => roles_path, :role_skip_facts => role_skip_facts}])
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
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        ansible-runner run
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @param tags [Hash] Hash with key/values pairs that will be passed as tags to the ansible-runner run
      # @param ansible_runner_method [String] Optional method we will use to run the ansible-runner. It can be either
      #        "run", which is sync call, or "start" which is async call.  Default is "run"
      # @param playbook_or_role_args [Hash] Hash that includes the :playbook key or :role keys
      # @return [Ansible::Runner::Response] Response object with all details about the ansible run
      def run_via_cli(env_vars, extra_vars, tags: nil, ansible_runner_method: "run", **playbook_or_role_args)
        validate_params!(env_vars, extra_vars, tags, ansible_runner_method, playbook_or_role_args)

        base_dir = Dir.mktmpdir("ansible-runner")
        params = runner_params(base_dir, ansible_runner_method, extra_vars, tags, playbook_or_role_args)

        begin
          result = AwesomeSpawn.run("ansible-runner", :env => env_vars, :params => params)
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

      def runner_params(base_dir, ansible_runner_method, extra_vars, tags, playbook_or_role_args)
        runner_args = playbook_or_role_args.dup

        runner_args.delete(:roles_path) if runner_args[:roles_path].nil?
        skip_facts = runner_args.delete(:role_skip_facts)
        runner_args[:role_skip_facts] = nil if skip_facts

        cmdline_commands = set_cmdline_commands(extra_vars, tags)

        runner_args[:ident]   = "result"
        runner_args[:hosts]   = "localhost"
        runner_args[:cmdline] = AwesomeSpawn.build_command_line(nil, [cmdline_commands]).lstrip if extra_vars.any?

        [ansible_runner_method, base_dir, :json, runner_args]
      end

      def set_cmdline_commands(extra_vars, tags)
        commands = {:extra_vars => extra_vars.to_json}
        commands[:tags] = tags if tags.present?

        commands
      end

      # Asserts passed parameters are correct, if not throws an exception.
      def validate_params!(env_vars, extra_vars, tags, ansible_runner_method, playbook_or_role_args)
        errors = []

        errors << "env_vars must be a Hash, got: #{hash.class}" unless env_vars.kind_of?(Hash)
        errors << "extra_vars must be a Hash, got: #{hash.class}" unless extra_vars.kind_of?(Hash)
        errors << "tags must be a String, got: #{tags.class}" if tags.present? && !tags.kind_of?(String)

        unless %w(run start).include?(ansible_runner_method.to_s)
          errors << "ansible_runner_method must be 'run' or 'start'"
        end

        unless playbook_or_role_args.keys == %i(playbook) || playbook_or_role_args.keys.sort == %i(role role_skip_facts roles_path)
          errors << "Unexpected playbook/role args: #{args}"
        end

        playbook = playbook_or_role_args[:playbook]
        errors << "playbook path doesn't exist: #{playbook}" if playbook && !File.exist?(playbook)
        roles_path = playbook_or_role_args[:roles_path]
        errors << "roles path doesn't exist: #{roles_path}" if roles_path && !File.exist?(roles_path)

        raise ArgumentError, errors.join("; ") if errors.any?
      end
    end
  end
end
