module TaskHelpers
  class Imports
    class Schedules
      def import(options = {})
        return unless options[:source]

        glob = File.file?(options[:source]) ? options[:source] : "#{options[:source]}/*.yaml"
        Dir.glob(glob) do |filename|
          $log.info("Importing Schedules from: #{filename}")

          begin
            MiqSchedule.import(File.open(filename, 'r'))
          rescue StandardError => err
            warn("Error importing #{filename} : #{err.message}")
          end
        end
      end
    end
  end
end
