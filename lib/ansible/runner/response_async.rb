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
      #        uniquely identify a playbook run. sWe use unique base dir per run, so this idrntifier can be static for
      #        most cases.
      def initialize(base_dir:, ident: "result")
        @base_dir = base_dir
        @ident    = ident
      end

      # @return [Boolean] true if the ansible job is still running, false when it's finished
      def running?

      end

      # @return [Ansible::Runner::Response] Response object with all details about the ansible run
      def response
        response = nil # TODO(lsmola) add Ansible::Runner::Response.new(...)

        FileUtils.remove_entry(base_dir) # Clean up the temp dir, when the response is generated

        response
      end

      def dump
        {
          :base_dir => base_dir,
          :ident    => ident
        }
      end

      def self.load(kwargs)
        self.new(kwargs)
      end
    end
  end
end
