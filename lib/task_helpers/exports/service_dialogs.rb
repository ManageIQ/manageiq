module TaskHelpers
  class Exports
    class ServiceDialogs
      def export(options = {})
        export_dir = options[:directory]

        dialogs = Dialog.order(:id).all

        dialogs.each do |dialog|
          $log.info("Exporting Service Dialog: #{dialog.name} (ID: #{dialog.id})")

          dialog_hash = DialogSerializer.new.serialize([dialog]).first
          dialog_hash["id"] = dialog.id
          dialog_hash["class"] = dialog.class.to_s
          dialog_hash = dialog_hash.symbolize_keys

          filename = Exports.safe_filename(dialog_hash, options[:keep_spaces], options[:super_safe_filename])
          File.write("#{export_dir}/#{filename}.yaml", dialog_hash.to_yaml)
        end
      end
    end
  end
end
