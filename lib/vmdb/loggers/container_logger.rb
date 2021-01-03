module Vmdb::Loggers
  class ContainerLogger < VMDBLogger
    include Instrument

    def initialize(logdev = STDOUT, *args)
      super
      self.level = DEBUG
      self.formatter = Formatter.new
    end

    def level=(_new_level)
      super(DEBUG) # We want everything written to the ContainerLogger written to STDOUT
    end

    def filename
      "STDOUT"
    end

    class Formatter < VMDBLogger::Formatter
      SEVERITY_MAP = {
        "DEBUG"   => "debug",
        "INFO"    => "info",
        "WARN"    => "warning",
        "ERROR"   => "err",
        "FATAL"   => "crit",
        "UNKNOWN" => "unknown"
        # Others that don't match up: alert emerg notice trace
      }.freeze

      def call(severity, time, progname, msg)
        # From https://github.com/ViaQ/elasticsearch-templates/releases -> Downloads -> *.asciidoc
        # NOTE: These values are in a specific order for easier human readbility via STDOUT
        payload = {
          :@timestamp => format_datetime(time),
          :hostname   => hostname,
          :pid        => $PROCESS_ID,
          :tid        => thread_id,
          :service    => progname,
          :level      => translate_error(severity),
          :message    => prefix_task_id(msg2str(msg)),
          # :tags => "tags string",
        }.delete_nils
        JSON.generate(payload) << "\n"
      end

      private

      def hostname
        @hostname ||= ENV["HOSTNAME"]
      end

      def thread_id
        Thread.current.object_id.to_s(16)
      end

      def translate_error(level)
        SEVERITY_MAP[level] || "unknown"
      end
    end
  end
end
