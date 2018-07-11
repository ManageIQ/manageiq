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
          mkdir(base_dir + '/project') # without this, there is a silent fail of the ansible-runner command see https://github.com/ansible/ansible-runner/issues/88

          result = AwesomeSpawn.run!(ansible_command(base_dir), :env => env_vars, :params => [{:cmdline => "--extra-vars '#{JSON.dump(extra_vars)}'", :playbook => playbook_path}])
          JSON.parse(result.output)
        end
      end

      def mkdir(base_dir)
        Dir.mkdir(base_dir) unless Dir.exist?(base_dir)
      end

      def ansible_command(base_dir)
        # TODO add possibility to use custom path, e.g. from virtualenv
        "ansible-runner run #{base_dir} --json"
      end
    end
  end
end
