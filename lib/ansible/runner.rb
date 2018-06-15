module Ansible
  class Runner
    class << self
      def run(env_vars, extra_vars, playbook_path)
        run_via_cli(env_vars, extra_vars, playbook_path)
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
