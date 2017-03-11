module TaskHelpers
  class Imports
    class AlertSets
      def import(options)
        glob = File.file?(options[:source]) ? options[:source] : "#{options[:source]}/*.yaml"
        Dir.glob(glob) do |fname|
          begin
            alertsets = YAML.load_file(fname)
            import_alert_sets(alertsets)
          rescue => e
            $stderr.puts "Error importing #{fname} : #{e.message}"
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
