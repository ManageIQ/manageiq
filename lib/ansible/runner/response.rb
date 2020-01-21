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
            data = JSON.parse(line)
            parsed_stdout << data if data.kind_of?(Hash)
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
        "".tap do |stdout|
          # Dir.glob for all `job_events`, and sort them by the "counter"
          # integer in the file name, which is the first digit(s) prior to a
          # '-' in the file.
          #
          #   job_events/1-2f97771f-c3d1-4123-8648-d035d48be4e8.json
          #   job_events/10-6f5dc948-c42f-4f3d-a357-151ec3e0b42e.json
          #   job_events/11-c0c9fdbe-8a69-4ac8-817b-19b567b514ac.json
          #   job_events/12-66c5f878-8fdc-4d76-9faf-2b42495a2636.json
          #   job_events/2-080027c4-9455-90b8-e116-000000000006.json
          #   job_events/3-080027c4-9455-90b8-e116-00000000000d.json
          #   ...
          #
          # And since `Dir.glob`'s sort order is operating system dependent, we
          # sort manually by the basename to ensure the proper order, and the
          # `File.basename` calls are done in a `.sort_by!` up front so they
          # aren't triggered for each block call in a traditional `.sort!`.
          #
          job_event_files = Dir.glob(File.join(base_dir, "artifacts", ident, "job_events", "*.json"))
                               .sort_by! { |fname| fname.match(%r{job_events/(\d+)})[1].to_i }

          # Read each file and added it to the `stdout` string.
          #
          # Also add a newline after each File read if one doesn't already
          # exist (`ansible-runner` is inconsistent with it's use of new-lines
          # at the end of files).
          job_event_files.each do |filename|
            stdout << File.read(filename)
            stdout << "\n" unless stdout[-1] == "\n"
          end
        end
      rescue
        _log.warn("Couldn't find ansible-runner stdout in #{base_dir}")
        ""
      end
    end
  end
end
