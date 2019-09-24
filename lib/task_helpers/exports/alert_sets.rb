module TaskHelpers
  class Exports
    class AlertSets
      def export(options = {})
        export_dir = options[:directory]

        MiqAlertSet.order(:id).all.each do |alert_set|
          $log.info("Exporting Alert Profile: #{alert_set.description} (ID: #{alert_set.id})")

          filename = Exports.safe_filename(alert_set.description, options[:keep_spaces])
          File.write("#{export_dir}/#{filename}.yaml", alert_set.export_to_yaml)
        end
      end
    end
  end
end
