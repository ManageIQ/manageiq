module TaskHelpers
  class Exports
    def self.new_filename(filename, keep_spaces = false)
      new_filename = filename
      new_filename = new_filename.gsub(%r{[ ]}, '_') unless keep_spaces
      new_filename = new_filename.gsub(%r{[/]}, 'slash')
      new_filename.gsub(%r{[|]}, 'pipe')
    end

    def self.parse_options
      require 'trollop'
      options = Trollop.options(EvmRakeHelper.extract_command_options) do
        opt :keep_spaces, 'Keep spaces in filenames', :type => :boolean, :short => 's', :default => false
        opt :directory, 'Directory to place exported files in', :type => :string, :required => true
      end

      error = validate_directory(options[:directory])
      Trollop.die :directory, error if error

      options
    end

    def self.validate_directory(directory)
      unless File.directory?(directory)
        return 'Destination directory must exist'
      end

      unless File.writable?(directory)
        return 'Destination directory must be writeable'
      end

      nil
    end
  end
end
