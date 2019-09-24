module TaskHelpers
  class Imports
    class Alerts
      def import(options)
        glob = File.file?(options[:source]) ? options[:source] : "#{options[:source]}/*.yaml"
        Dir.glob(glob) do |filename|
          $log.info("Importing Alerts from: #{filename}")

          begin
            alerts = YAML.load_file(filename)
            import_alerts(alerts)
          rescue StandardError => err
            $log.error("Error importing #{filename} : #{err.message}")
            warn("Error importing #{filename} : #{err.message}")
          end
        end
      end

      private

      def import_alerts(alerts)
        MiqAlert.transaction do
          alerts.each do |alert|
            MiqAlert.import_from_hash(alert['MiqAlert'], :preview => false)
          end
        end
      end
    end
  end
end
