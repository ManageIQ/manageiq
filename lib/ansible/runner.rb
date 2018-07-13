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
        result = AwesomeSpawn.run!(ansible_command, :env => env_vars, :params => [{:extra_vars => JSON.dump(extra_vars)}, playbook_path])
        JSON.parse(result.output)
      end

      def ansible_command
        # TODO add possibility to use custom path, e.g. from virtualenv
        "ansible-playbook"
      end
    end
  end
end
