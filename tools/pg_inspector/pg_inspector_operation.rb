module PgInspector
  class PgInspectorOperation
    HELP_MSG_SHORT = ''.freeze
    DEFAULT_OUTPUT_PATH = (File.dirname(__FILE__) + "/output/").freeze
    attr_accessor :options

    def parse_options(args)
    end

    def run
    end
  end
end
