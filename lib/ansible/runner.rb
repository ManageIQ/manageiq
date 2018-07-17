module Ansible
  class Runner
    class << self
      def run(env_vars, extra_vars, playbook_path)
        run_via_cli(env_vars, extra_vars, playbook_path)
      end

      def run_queue(env_vars, extra_vars, playbook_path, user_id, queue_opts)
        queue_opts = {
          :args        => [env_vars, extra_vars, playbook_path],
          :queue_name  => "generic",
          :class_name  => name,
          :method_name => "run",
        }.merge(queue_opts)

        task_opts = {
          :action => "Run Ansible Playbook",
          :userid => user_id,
        }

        MiqTask.generic_action_with_callback(task_opts, queue_opts)
      end

      private

      def run_via_cli(env_vars, extra_vars, playbook_path)
        Dir.mktmpdir("ansible-runner") do |base_dir|
          Dir.mkdir(File.join(base_dir, 'project')) # without this, there is a silent fail of the ansible-runner command see https://github.com/ansible/ansible-runner/issues/88

          result = AwesomeSpawn.run!(ansible_command(base_dir),
                                     :env    => env_vars,
                                     :params => [{:cmdline  => "--extra-vars '#{JSON.dump(extra_vars)}'",
                                                  :playbook => playbook_path}])

          Ansible::Runner::Response.new(:return_code => return_code(base_dir),
                                        :stdout      => result.output,
                                        :stderr      => result.error)
        end
      end

      def return_code(base_dir)
        File.read(File.join(base_dir, "artifacts/result/rc")).to_i
      rescue
        _log.warn("Couldn't find ansible-runner return code")
        1
      end

      def ansible_command(base_dir)
        # TODO add possibility to use custom path, e.g. from virtualenv
        "ansible-runner run #{base_dir} --json -i result"
      end
    end
  end
end
