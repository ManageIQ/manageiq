require 'optimist'

module MiqConfigSssdLdap
  class CliError < StandardError; end

  class Cli
    attr_accessor :opts

    def run
      Converter.new(opts).run
    end

    def self.run(args)
      new.parse(args).run
    end

    def parse(_args)
      raise NotImplementedError, _("parse must be implemented in a subclass")
    end
  end
end
