module TaskHelpers
  class Imports
    def self.parse_options
      require 'optimist'
      options = Optimist.options(EvmRakeHelper.extract_command_options) do
        opt :source, 'Directory or file to import from', :type => :string, :required => true
        opt :overwrite, 'Overwrite existing object', :type => :boolean, :default => true
        opt :connect_dialog_by_name, 'for custom buttons: in case dialog with exported name exist, connect it'
      end

      error = validate_source(options[:source])
      Optimist.die :source, error if error

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
