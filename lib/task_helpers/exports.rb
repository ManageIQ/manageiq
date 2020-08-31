module TaskHelpers
  class Exports
    def self.safe_filename(filename, keep_spaces = false)
      new_filename = keep_spaces ? filename : filename.gsub(%r{[ ]}, '_')
      new_filename.gsub(%r{[|/]}, '/' => 'slash', '|' => 'pipe')
    end

    def self.parse_options
      require 'optimist'
      options = Optimist.options(EvmRakeHelper.extract_command_options) do
        opt :keep_spaces, 'Keep spaces in filenames', :type => :boolean, :short => 's', :default => false
        opt :directory, 'Directory to place exported files in', :type => :string, :required => true
        opt :all, 'Export read-only objects', :type => :boolean, :default => false
      end

      options[:directory] = File.absolute_path(options[:directory])

      error = validate_directory(options[:directory])
      Optimist.die :directory, error if error

      options
    end

    def self.validate_directory(directory)
      unless File.directory?(directory)
        return 'Destination directory must exist'
      end

      unless File.writable?(directory)
        return 'Destination directory must be writable'
      end

      nil
    end

    def self.exclude_attributes(attributes, excluded_attributes)
      attributes.reject { |key, _| excluded_attributes.include?(key) }
    end
  end
end
