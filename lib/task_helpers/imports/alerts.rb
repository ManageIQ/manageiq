module TaskHelpers
  class Imports
    class Alerts
      def import(options)
        glob = File.file?(options[:source]) ? options[:source] : "#{options[:source]}/*.yaml"
        Dir.glob(glob) do |fname|
          begin
            alerts = YAML.load_file(fname)
            import_alerts(alerts)
          rescue => e
            $stderr.puts "Error importing #{fname} : #{e.message}"
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
