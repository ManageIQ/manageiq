module TaskHelpers
  class Imports
    class ServiceDialogs
      def import(options = {})
        return unless options[:source]

        glob = File.file?(options[:source]) ? options[:source] : "#{options[:source]}/*.yaml"
        Dir.glob(glob) do |filename|
          $log.info("Importing Service Dialogs from: #{filename}")

          DialogImportService.new.import_from_file(filename)
        end
      end
    end
  end
end
