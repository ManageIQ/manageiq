module Ansible
  class Runner
    class Response
      include Vmdb::Logging

      attr_reader :return_code, :stdout, :stderr, :parsed_stdout

      # Response object designed for holding full response from ansible-runner
      #
      # @param return_code [Integer] Return code of the ansible-runner run, 0 == ok, others mean failure
      # @param stdout [String] Stdout from ansible-runner run
      # @param stderr [String] Stderr from ansible-runner run
      def initialize(return_code:, stdout:, stderr:)
        @return_code   = return_code
        @stdout        = stdout
        @parsed_stdout = parse_stdout(stdout)
        @stderr        = stderr
      end

      private

      # Parses stdout to array of hashes
      #
      # @param stdout [String] Stdout that is text, where each line should be JSON encoded object
      # @return [Array<Hash>] Array of hashes as individual Ansible plays
      def parse_stdout(stdout)
        parsed_stdout = []

        # output is JSON per new line
        stdout.each_line do |line|
          # TODO(lsmola) we can remove exception handling when this is fixed
          # https://github.com/ansible/ansible-runner/issues/89#issuecomment-404236832 , so it fails early if there is
          # a non json line
          begin
            parsed_stdout << JSON.parse(line)
          rescue => e
            _log.warn("Couldn't parse JSON from: #{e}")
          end
        end

        parsed_stdout
      end
    end
  end
end
