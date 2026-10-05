module Ansible
  class Runner
    # Holds the result of a completed ansible-runner execution.
    #
    # Both +return_code+ and +stdout+ are always provided at construction time
    # from the container runner's exit code and captured STDOUT stream.
    # There is no filesystem to read from in the container execution model.
    class Response
      include Vmdb::Logging

      attr_reader :return_code, :stdout

      # @param return_code [Integer] Exit code of the ansible-runner process. 0 = success.
      # @param stdout [String] Newline-delimited JSON event stream from ansible-runner --json.
      def initialize(return_code:, stdout:)
        @return_code = return_code
        @stdout      = stdout
      end

      # @return [Array<Hash>] Parsed array of ansible-runner event objects
      def parsed_stdout
        @parsed_stdout ||= parse_stdout(stdout)
      end

      # @return [String] Human-readable stdout extracted from the JSON event stream
      def human_stdout
        @human_stdout ||= self.class.parsed_stdout_to_human(parsed_stdout)
      end

      # @return [Array<Hash>] Parsed event data for each play start event
      def plays
        @plays ||= self.class.parsed_stdout_to_plays(parsed_stdout)
      end

      # @return [Hash] Artifact data set via Ansible set_stats
      def stats
        @stats ||= self.class.parsed_stdout_to_stats(parsed_stdout)
      end

      # @param parsed_stdout [Array<Hash>] Array returned by #parsed_stdout
      # @return [Array<Hash>] Array of playbook_on_play_start events
      def self.parsed_stdout_to_plays(parsed_stdout)
        parsed_stdout.select { |e| e["event"] == "playbook_on_play_start" }
      end

      # @param parsed_stdout [Array<Hash>] Array returned by #parsed_stdout
      # @return [Hash] Artifact data hash or empty hash if not present
      def self.parsed_stdout_to_stats(parsed_stdout)
        stats_event = parsed_stdout.detect { |e| e["event"] == "playbook_on_stats" }
        stats_event&.dig("event_data", "artifact_data") || {}
      end

      # @param parsed_stdout [Array<Hash>] Array returned by #parsed_stdout
      # @return [String] Concatenated human-readable lines
      def self.parsed_stdout_to_human(parsed_stdout)
        parsed_stdout.pluck("stdout").join("\n")
      end

      private

      # Parses the newline-delimited JSON stdout stream into an array of hashes
      def parse_stdout(stdout)
        stdout.each_line.map do |line|
          data = JSON.parse(line)
          if data.kind_of?(Hash)
            data
          else
            {"stdout" => line.chomp}
          end
        rescue JSON::ParserError
          {"stdout" => line.chomp}
        end
      end
    end
  end
end
