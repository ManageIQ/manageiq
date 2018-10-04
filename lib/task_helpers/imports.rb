module TaskHelpers
  class Imports
    def self.parse_options
      require 'trollop'
      options = Trollop.options(EvmRakeHelper.extract_command_options) do
        opt :source, 'Directory or file to import from', :type => :string, :required => true
        opt :overwrite, 'Overwrite existing objects', :type => :boolean, :short => 'o', :default => false
      end

      error = validate_source(options[:source])
      Trollop.die :source, error if error

      options
    end

    def self.parse_custom_button_options
      require 'trollop'
      options = Trollop.options(EvmRakeHelper.extract_command_options) do
        opt :overwrite, 'Overwrite existing models', :type => :boolean, :required => false, :default => false
        opt :source, 'Directory or file to import from', :type => :string, :required => true
      end

      error = validate_source(options[:source])
      Trollop.die :source, error if error

      options
    end

    def self.validate_source(source)
      unless File.directory?(source) || File.file?(source)
        return 'Import source must be a filename or directory'
      end

      unless File.readable?(source)
        return 'Import source is not readable'
      end

      nil
    end
  end
end
