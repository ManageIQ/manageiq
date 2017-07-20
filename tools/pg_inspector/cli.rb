require 'trollop'
require 'pg_inspector/util'
require 'pg_inspector/active_connections_to_yaml'

module PgInspector
  class Cli
    attr_accessor :cmd
    SUB_COMMANDS = {
      :active_connections => ::PgInspector::ActiveConnectionsYAML
    }.freeze

    def self.run(args)
      new.parse(args).cmd.run
    end

    def parse(args)
      args.shift if args.first == "--" # Handle when called through script/runner
      op_help = operation_help
      Trollop.options(args) do
        banner <<-BANNER
pg_inspector is a tool to inspect ManageIQ process caused deadlock in PostgreSQL.

  Usage:
    #{$PROGRAM_NAME} operation options_for_operation
    #{$PROGRAM_NAME} options

  Operations:
#{op_help}
  Use `pg_inspector.rb operation -h' to see help for each operation

  Options:
BANNER
        stop_on(SUB_COMMANDS.keys.map(&:to_s))
      end
      current_operation = SUB_COMMANDS[args.shift.to_sym]
      if current_operation
        self.cmd = current_operation.new
      else
        Trollop.educate
      end
      cmd.parse_options(args)
      self
    end

    private

    def operation_help
      result = ''
      SUB_COMMANDS.each do |command, klass|
        result << "    #{command}\t\t#{klass::HELP_MSG_SHORT}\n"
      end
      result
    end
  end
end
