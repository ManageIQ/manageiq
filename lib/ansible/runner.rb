module Ansible
  class Runner
    class << self
      def run(env_vars, extra_vars, playbook_path)
        run_via_cli(env_vars, extra_vars, :playbook_path => playbook_path)
      end

      def run_role(env_vars, extra_vars, role_name, roles_path:, role_skip_facts: true)
        run_via_cli(env_vars, extra_vars, :role_name => role_name, :roles_path => roles_path, :role_skip_facts => role_skip_facts)
      end

      def run_queue(env_vars, extra_vars, playbook_path, user_id, queue_opts)
        run_in_queue("run", user_id, queue_opts, [env_vars, extra_vars, playbook_path])
      end

      def run_role_queue(env_vars, extra_vars, role_name, user_id, queue_opts, roles_path:, role_skip_facts: true)
        run_in_queue("run_role",
                     user_id,
                     queue_opts,
                     [env_vars, extra_vars, role_name, {:roles_path => roles_path, :role_skip_facts => role_skip_facts}])
      end

      private

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

      def playbook_params(playbook_path: playbook_path)
        {:playbook => playbook_path}
      end

      def role_params(role_name:, roles_path:, role_skip_facts:)
        role_params = {:role => role_name}

        role_params[:"roles-path"] = roles_path if roles_path
        role_params[:"role-skip-facts"] = nil if role_skip_facts

        role_params
      end

      def shared_params(extra_vars:)
        {:cmdline => "--extra-vars '#{JSON.dump(extra_vars)}'"}
      end

      def return_code(base_dir)
        File.read(File.join(base_dir, "artifacts/result/rc")).to_i
      rescue
        _log.warn("Couldn't find ansible-runner return code")
        1
      end

      def validate_params!(env_vars, extra_vars, playbook_path, roles_path)
        assert_hash!(env_vars)
        assert_hash!(extra_vars)
        assert_path!(playbook_path)
        assert_path!(roles_path)
      end

      def assert_hash!(hash)
        unless hash.kind_of?(Hash)
          raise "Passed parameter must be of type Hash, got: #{hash}"
        end
      end

      def assert_path!(path)
        return unless path

        unless File.exist?(path)
          raise "File doesn't exist: #{path}"
        end
      end

      def ansible_command(base_dir)
        "ansible-runner run #{base_dir} --json -i result --hosts localhost"
      end
    end
  end
end
