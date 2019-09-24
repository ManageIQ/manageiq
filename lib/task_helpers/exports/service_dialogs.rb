module TaskHelpers
  class Exports
    class ServiceDialogs
      def export(options = {})
        export_dir = options[:directory]

        dialogs = Dialog.order(:id).all

        dialogs.each do |dialog|
          $log.info("Exporting Service Dialog: #{dialog.name} (ID: #{dialog.id})")

          dialog_hash = DialogSerializer.new.serialize([dialog])

          filename = Exports.safe_filename(dialog_hash.first['label'], options[:keep_spaces])
          File.write("#{export_dir}/#{filename}.yaml", dialog_hash.to_yaml)
        end
      end
    end
  end
end
