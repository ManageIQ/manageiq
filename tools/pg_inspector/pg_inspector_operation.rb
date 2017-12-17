require 'pathname'

module PgInspector
  class PgInspectorOperation
    HELP_MSG_SHORT = ''.freeze
    DEFAULT_OUTPUT_PATH = Pathname.new(__dir__).join("../../log").freeze
    PREFIX = 'pg_inspector_'.freeze
    attr_accessor :options

    def parse_options(args)
    end

    def run
    end
  end
end
