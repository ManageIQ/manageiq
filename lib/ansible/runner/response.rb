module Ansible
  class Runner
    class Response
      include Vmdb::Logging

      attr_reader :base_dir, :ident

      # Response object designed for holding full response from ansible-runner
      #
      # @param base_dir [String] ansible-runner private_data_dir parameter
      # @param return_code [Integer] Return code of the ansible-runner run, 0 == ok, others mean failure
      # @param stdout [String] Stdout from ansible-runner run
      # @param stderr [String] Stderr from ansible-runner run
      # @param ident [String] ansible-runner ident parameter
      def initialize(base_dir:, return_code: nil, stdout: nil, stderr: nil, ident: "result")
        @base_dir      = base_dir
        @ident         = ident
        @return_code   = return_code
        @stdout        = stdout
        @parsed_stdout = parse_stdout(stdout) if stdout
        @stderr        = stderr
      end

      # @return [Integer] Return code of the ansible-runner run, 0 == ok, others mean failure
      def return_code
        @return_code ||= load_return_code
      end

      # @return [String] Stdout that is text, where each line should be JSON encoded object
      def stdout
        @stdout ||= load_stdout
      end

      # @return [Array<Hash>] Array of hashes as individual Ansible plays
      def parsed_stdout
        @parsed_stdout ||= parse_stdout(stdout)
      end

      # Loads needed data from the filesystem and deletes the ansible-runner base dir
      def cleanup_filesystem!
        # Load all needed files, before we cleanup the dir
        return_code
        stdout

        FileUtils.remove_entry(base_dir)
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

      # Reads a return code from a file used by ansible-runner
      #
      # @return [Integer] Return code of the ansible-runner run, 0 == ok, others mean failure
      def load_return_code
        File.read(File.join(base_dir, "artifacts", ident, "rc")).to_i
      rescue
        _log.warn("Couldn't find ansible-runner return code in #{base_dir}")
        1
      end

      # @return [String] Stdout that is text, where each line should be JSON encoded object
      def load_stdout
        File.read(File.join(base_dir, "artifacts", ident, "stdout"))
      rescue
        _log.warn("Couldn't find ansible-runner stdout in #{base_dir}")
        ""
      end
    end
  end
end
