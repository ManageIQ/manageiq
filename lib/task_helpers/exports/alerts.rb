module TaskHelpers
  class Exports
    class Alerts
      def export(options = {})
        export_dir = options[:directory]

        MiqAlert.order(:id).all.each do |alert|
          $log.info("Exporting Alert: #{alert.description} (ID: #{alert.id})")

          filename = Exports.safe_filename(alert.description, options[:keep_spaces])
          File.write("#{export_dir}/#{filename}.yaml", alert.export_to_yaml)
        end
      end
    end
  end
end
