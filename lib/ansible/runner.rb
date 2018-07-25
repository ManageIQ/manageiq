module Ansible
  class Runner
    class << self
      # Runs a playbook via ansible-runner, see: https://ansible-runner.readthedocs.io/en/latest/standalone.html#running-playbooks
      #
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        ansible-runner run
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @param playbook_path [String] Path to the playbook we will want to run
      # @return [Ansible::Runner::Response] Response object with all details about the ansible run
      def run(env_vars, extra_vars, playbook_path)
        run_via_cli(env_vars, extra_vars, :playbook_path => playbook_path)
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
      # @return [Ansible::Runner::Response] Response object with all details about the ansible run
      def run_role(env_vars, extra_vars, role_name, roles_path:, role_skip_facts: true)
        run_via_cli(env_vars, extra_vars, :role_name => role_name, :roles_path => roles_path, :role_skip_facts => role_skip_facts)
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
        run_in_queue("run_role",
                     user_id,
                     queue_opts,
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
      # @param playbook_path [String] Path to the playbook we will want to run
      # @param role_name [String] Ansible role name
      # @param roles_path [String] Path to the directory with roles
      # @param role_skip_facts [Boolean] Whether we should skip facts gathering, equals to 'gather_facts: False' in a
      #        playbook. True by default.
      # @return [Ansible::Runner::Response] Response object with all details about the ansible run
      def run_via_cli(env_vars, extra_vars, playbook_path: nil, role_name: nil, roles_path: nil, role_skip_facts: true)
        validate_params!(env_vars, extra_vars, playbook_path, roles_path)

        Dir.mktmpdir("ansible-runner") do |base_dir|
          result = AwesomeSpawn.run(ansible_command(base_dir),
                                    :env    => env_vars,
                                    :params => params(:extra_vars      => extra_vars,
                                                      :playbook_path   => playbook_path,
                                                      :role_name       => role_name,
                                                      :roles_path      => roles_path,
                                                      :role_skip_facts => role_skip_facts))

          Ansible::Runner::Response.new(:return_code => return_code(base_dir),
                                        :stdout      => result.output,
                                        :stderr      => result.error)
        end
      end

      # Generate correct params, depending if we've passed :playbook_path or a :role_name
      #
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @param playbook_path [String] Path to the playbook we will want to run
      # @param role_name [String] Ansible role name
      # @param roles_path [String] Path to the directory with roles
      # @param role_skip_facts [Boolean] Whether we should skip facts gathering, equals to 'gather_facts: False' in a
      #        playbook.
      # @return [Array] Arguments for the ansible-runner run
      def params(extra_vars:, playbook_path:, role_name:, roles_path:, role_skip_facts:)
        role_or_playbook_params = if playbook_path
                                    playbook_params(:playbook_path => playbook_path)
                                  elsif role_name
                                    role_params(:role_name       => role_name,
                                                :roles_path      => roles_path,
                                                :role_skip_facts => role_skip_facts)
                                  end

        [shared_params(:extra_vars => extra_vars).merge(role_or_playbook_params)]
      end

      # Generate correct params if using :playbook_path
      #
      # @param playbook_path [String] Path to the playbook we will want to run
      # @return [Hash] Partial arguments for the ansible-runner run
      def playbook_params(playbook_path:)
        {:playbook => playbook_path}
      end

      # Generate correct params if using :role_name
      #
      # @param role_name [String] Ansible role name
      # @param roles_path [String] Path to the directory with roles
      # @param role_skip_facts [Boolean] Whether we should skip facts gathering, equals to 'gather_facts: False' in a
      #        playbook.
      # @return [Hash] Partial arguments for the ansible-runner run
      def role_params(role_name:, roles_path:, role_skip_facts:)
        role_params = {:role => role_name}

        role_params[:"roles-path"] = roles_path if roles_path
        role_params[:"role-skip-facts"] = nil if role_skip_facts

        role_params
      end

      # Generate correct params shared by :playbook_path or a :role_name paths
      #
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @return [Hash] Partial arguments for the ansible-runner run
      def shared_params(extra_vars:)
        {:cmdline => "--extra-vars '#{JSON.dump(extra_vars)}'"}
      end

      # Reads a return code from a file used by ansible-runner
      #
      # @return [Integer] Return code of the ansible-runner run, 0 == ok, others mean failure
      def return_code(base_dir)
        File.read(File.join(base_dir, "artifacts/result/rc")).to_i
      rescue
        _log.warn("Couldn't find ansible-runner return code")
        1
      end

      # Asserts passed parameters are correct, if not throws an exception.
      #
      # @param env_vars [Hash] Hash with key/value pairs that will be passed as environment variables to the
      #        ansible-runner run
      # @param extra_vars [Hash] Hash with key/value pairs that will be passed as extra_vars to the ansible-runner run
      # @param playbook_path [String] Path to the playbook we will want to run
      # @param roles_path [String] Path to the directory with roles
      def validate_params!(env_vars, extra_vars, playbook_path, roles_path)
        assert_hash!(env_vars)
        assert_hash!(extra_vars)
        assert_path!(playbook_path)
        assert_path!(roles_path)
      end

      # Asserts that passed argument is a hash
      #
      # @param hash [Hash] Passed argument we test for being Hash
      def assert_hash!(hash)
        unless hash.kind_of?(Hash)
          raise "Passed parameter must be of type Hash, got: #{hash}"
        end
      end

      # Asserts that passed path exists
      #
      # @param path [Hash, NilClass] Passed path we test for existence
      def assert_path!(path)
        return unless path

        unless File.exist?(path)
          raise "File doesn't exist: #{path}"
        end
      end

      # @return [String] ansible_runner executable command
      def ansible_command(base_dir)
        "ansible-runner run #{base_dir} --json -i result --hosts localhost"
      end
    end
  end
end
