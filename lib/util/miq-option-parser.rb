require 'rubygems'
require 'optparse'

module MiqOptionParser
  class PartialMatchHash < Hash
    def [](key_name)
      return fetch(key_name) if keys.include?(key_name)
      matches = keys.select {|key| key =~ /^#{key_name}.*/ }
      return nil unless matches.size == 1
      return fetch(matches.first)
    end
  end

  class MiqCommand
    attr_reader   :name, :default_command, :commands
    attr_accessor :short_desc, :description, :option_parser, :parent

    def initialize(name, command_parser = nil)
      @name            = name
      @option_parser   = OptionParser.new
      @default_command = nil
      @commands        = PartialMatchHash.new
      @command_parser  = command_parser
    end
    
    def command_parser
      @command_parser ||= parent.command_parser
    end

    def has_commands?
      @commands.keys.length > 0
    end
    
    def add_command(command, default = false)
      @commands[command.name] = command
      @default_command        = command.name if default
      command.parent          = self
      command.post_initialize if command.respond_to?("post_initialize")
    end

    def <=>(other)
      @name <=> other.name
    end

    def parents
      cmds = []
      cmd  = self
      while not cmd.nil?
        cmds << cmd
        cmd = cmd.parent
      end
      cmds
    end
    
    #######
    private
    #######

    def print_commands( level = 1, command = self )
      puts "Available commands:" if level == 1
      command.commands.sort.each do |name, cmd|
        print "  "*level + name.ljust( 15 ) + cmd.short_desc.to_s
        print " (=default command)" if name == command.default_command
        print "\n"
        print_commands( level + 1, cmd ) if cmd.has_commands?
      end
    end
    
  end

  class MiqCommandParser
    attr_accessor :banner, :program_name, :program_version, :handle_exceptions, :exit_on_help, :exit_on_version
    attr_reader   :root_command

    def initialize
      @program_name      = $0
      @program_version   = "0.0.0"
      @handle_exceptions = false
      @exit_on_help      = true
      @exit_on_version   = true
      @root_command      = MiqCommand.new('root', self)
      add_command(DefaultHelpCommand.new)
  		add_command(DefaultVersionCommand.new)
    end

    def option_parser
      @root_command.option_parser
    end
    
    def option_parser=(parser)
      @root_command.option_parser = parser
    end

    def add_command(*args)
      @root_command.add_command(*args)
    end

    def help
      @root_command.commands['help']
    end
    
    def parse(argv = ARGV)
      depth   = 0
      command = @root_command

      while !command.nil?
        argv = command.has_commands? ? command.option_parser.order(argv) : command.option_parser.permute(argv)
        yield(depth, command.name) if block_given?

        if command.has_commands?
          cmdName, argv = argv[0], argv[1..-1] || []

          if cmdName.nil?
            raise NoCommandGivenError if command.default_command.nil?
            cmdName = command.default_command
          end

          raise InvalidCommandError.new(cmdName) unless command.commands[cmdName]
          command = command.commands[cmdName]
          depth += 1
        else
          command.execute(argv)
          command = nil
        end
      end
    rescue ParseError, OptionParser::ParseError => e
      raise if @handle_exceptions == false
      puts "Error while parsing command line:\n    #{e.message}\n"
      help.execute(command.parents.reverse.collect {|c| c.name}) unless help.nil?
      exit
    end
    
  end

  # Base class for all MiqOptionParser errors.
  class ParseError < RuntimeError

    # Sets the reason for a subclass.
    def self.reason( reason, has_arguments = true )
      (@@reason ||= {})[self] = [reason, has_arguments]
    end

    # Returns the reason plus the message.
    def message
      data = @@reason[self.class] || ['Unknown error', true]
      data[0] + (data[1] ? ": " + super : '')
    end

  end


  class DefaultHelpCommand < MiqCommand
    def initialize
      super('help')
      self.short_desc  = 'Provide help for individual commands'
      self.description = 'This command prints the program help if no arguments are given. ' \
      'If one or more command names are given as arguments, these arguments are interpreted ' \
      'as a hierachy of commands and the help for the right most command is show.'
    end
    
    def post_initialize
      self.command_parser.root_command.option_parser.on_tail( "-h", "--help", "Show help" ) do
        execute( [] )
      end
    end

    def usage
      "Usage: #{self.command_parser.program_name} help [COMMAND SUBCOMMAND ...]"
    end

    def execute( args )
      if args.length > 0
        cmd = self.command_parser.root_command
        arg = args.shift
        while !arg.nil? && cmd.commands[ arg ]
          cmd = cmd.commands[arg]
          arg = args.shift
        end
        if arg.nil?
          cmd.show_help
        else
          raise InvalidArgumentError, args.unshift( arg ).join(' ')
        end
      else
        show_program_help
      end
      exit  if self.command_parser.exit_on_help == true
    end

    #######
    private
    #######

    def show_program_help
      puts self.command_parser.banner + "\n" if self.command_parser.banner
      puts "Usage: #{self.command_parser.program_name} [options] COMMAND [options] [COMMAND [options] ...] [args]"
      puts ""
      print_commands( 1, self.command_parser.root_command )
      puts ""
      puts self.command_parser.root_command.option_parser.summarize
      puts
    end
  end

  class DefaultVersionCommand < MiqCommand
    def initialize
      super('version')
      self.short_desc = "Show the version of the program"
    end
    
    def post_initialize
      self.command_parser.root_command.option_parser.on_tail( "--version", "-v", "Show the version of the program" ) do
        execute( [] )
      end
    end

    def usage
      "Usage: #{self.command_parser.program_name} version"
    end

    def execute( args )
      version = self.command_parser.program_version
      version = version.join( '.' ) if version.instance_of?( Array )
      puts self.command_parser.banner + "\n" if self.command_parser.banner
      puts version
      exit if self.command_parser.exit_on_version == true
    end
  end

end
