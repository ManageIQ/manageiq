module TaskHelpers
  class Imports
    class GenericObjectDefinitions
      def import(options = {})
        return unless options[:source]

        glob = File.file?(options[:source]) ? options[:source] : "#{options[:source]}/*.yaml"
        Dir.glob(glob) do |filename|
          $log.info("Importing Generic Object Definitions from: #{filename}")

          god_options = {:overwrite => options[:overwrite]}

          begin
            god_fd = File.open(filename, 'r')
            GenericObjectDefinition.import(god_fd, god_options)
          rescue ActiveModel::UnknownAttributeError, RuntimeError => err
            $log.error("Error importing #{filename} : #{err.message}")
            warn("Error importing #{filename} : #{err.message}")
          end
        end
      end
    end
  end
end
