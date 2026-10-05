module Ansible
  class Runner
    # Async response backed by a Floe container runner.
    # Implements the running?/stop/response/dump/load interface expected by
    # AnsibleRunnerWorkflow's poll loop.
    class ResponseAsync
      include Vmdb::Logging

      attr_reader :runner_class, :runner_context, :base_dir, :debug

      # @param runner_class [Class, String] The Floe runner class, or its fully-qualified
      #        name (e.g. "Floe::ContainerRunner::Docker").
      # @param runner_context [Hash] Opaque hash returned by Floe::Runner#run_async!
      # @param base_dir [String] Path to the ansible-runner private_data_dir that was
      #        volume-mounted into the container. Cleaned up after the run.
      # @param debug [Boolean] When true, base_dir is NOT removed after the run
      def initialize(runner_class:, runner_context:, base_dir:, debug: false)
        @runner_class   = runner_class.is_a?(String) ? runner_class.constantize : runner_class
        @runner_context = runner_context
        @base_dir       = base_dir
        @debug          = debug
      end

      # @return [Boolean] true if the container is still running
      def running?
        runner.status!(runner_context)
        runner.running?(runner_context)
      end

      # Stops the running container and removes the base_dir.
      def stop
        runner.cleanup(runner_context)
        remove_base_dir
      end

      # @return [Ansible::Runner::Response, nil] Response when the container has
      #         finished, nil if it is still running.
      def response
        return if running?
        return @response if @response

        stdout      = runner.output(runner_context).to_s
        return_code = runner.success?(runner_context) ? 0 : 1

        runner.cleanup(runner_context)
        remove_base_dir

        @response = Ansible::Runner::Response.new(
          :return_code => return_code,
          :stdout      => stdout
        )
      end

      # Blocks until the container finishes, then returns the Response.
      #
      # @param poll_interval [Numeric] seconds to sleep between status checks
      # @return [Ansible::Runner::Response]
      def wait(poll_interval: 0.5)
        sleep(poll_interval) while running?
        response
      end

      # Serialises this object to a plain hash so it can be stored in the job
      # context and later reloaded via .load.
      #
      # @return [Hash]
      def dump
        {
          :runner_class   => runner_class.name,
          :runner_context => runner_context,
          :base_dir       => base_dir.to_s,
          :debug          => debug
        }
      end

      # Recreates a ResponseAsync from a previously dumped hash.
      #
      # @param hash [Hash] Value returned by #dump
      # @return [Ansible::Runner::ResponseAsync]
      def self.load(hash)
        new(**hash.transform_keys(&:to_sym))
      end

      private

      def runner
        @runner ||= runner_class.new
      end

      def remove_base_dir
        return if debug || base_dir.blank?

        FileUtils.remove_entry(base_dir)
      rescue => err
        _log.warn("Failed to remove ansible runner base_dir #{base_dir}: #{err}")
      end
    end
  end
end
