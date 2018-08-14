module TaskHelpers
  class Imports
    class AlertSets
      def import(options)
        glob = File.file?(options[:source]) ? options[:source] : "#{options[:source]}/*.yaml"
        Dir.glob(glob) do |filename|
          $log.info("Importing Alert Profiles from: #{filename}")

          begin
            alertsets = YAML.load_file(filename)
            import_alert_sets(alertsets)
          rescue StandardError => err
            $log.error("Error importing #{filename} : #{err.message}")
            warn("Error importing #{filename} : #{err.message}")
          end
        end
      end

      private

      def import_alert_sets(alertsets)
        MiqAlertSet.transaction do
          alertsets.each do |alertset|
            MiqAlertSet.import_from_hash(alertset['MiqAlertSet'], :preview => false)
          end
        end
      end
    end
  end
end
