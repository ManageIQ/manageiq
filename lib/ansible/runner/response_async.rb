module Ansible
  class Runner
    class ResponseAsync
      include Vmdb::Logging

      attr_reader :base_dir, :ident

      # Response object designed for holding full response from ansible-runner
      #
      # @param base_dir [String] Base directory containing Runner metadata (project, inventory, etc). ansible-runner
      #        refers to it as 'private_data_dir'
      # @param ident [String] An identifier that will be used when generating the artifacts directory and can be used to
      #        uniquely identify a playbook run. We use unique base dir per run, so this identifier can be static for
      #        most cases.
      def initialize(base_dir:, ident: "result")
        @base_dir = base_dir
        @ident    = ident
      end

      # @return [Boolean] true if the ansible job is still running, false when it's finished
      def running?
        AwesomeSpawn.run("ansible-runner", :params => ["is-alive", base_dir, :json, {:ident => "result"}]).success?
      end

      # Stops the running Ansible job
      def stop
        AwesomeSpawn.run("ansible-runner", :params => ["stop", base_dir, :json, {:ident => "result"}])
      end

      # @return [Ansible::Runner::Response, NilClass] Response object with all details about the Ansible run, or nil
      #         if the Ansible is still running
      def response
        return if running?
        return @response if @response

        @response = Ansible::Runner::Response.new(:base_dir => base_dir, :ident => ident)
        @response.cleanup_filesystem!

        @response
      end

      # Dumps the Ansible::Runner::ResponseAsync into the hash
      #
      # @return [Hash] Dumped Ansible::Runner::ResponseAsync object
      def dump
        {
          :base_dir => base_dir,
          :ident    => ident
        }
      end

      # Creates the Ansible::Runner::ResponseAsync object from hash data
      #
      # @param [Hash] Dumped Ansible::Runner::ResponseAsync object
      # @return [Ansible::Runner::ResponseAsync] Ansible::Runner::ResponseAsync Object created from hash data
      def self.load(kwargs)
        new(kwargs)
      end
    end
  end
end
