module TaskHelpers
  class Exports
    class ProvisionDialogs
      EXCLUDE_ATTRS = %i(file_mtime created_at updated_at id class).freeze
      def export(options = {})
        export_dir = options[:directory]

        dialogs = options[:all] ? MiqDialog.all : MiqDialog.where(:default => [false, nil])

        dialogs.order(:id).each do |dialog|
          $log.info("Exporting #{dialog.dialog_type} Provision Dialog: #{dialog.name} (ID: #{dialog.id})")

          dialog_hash = Exports.exclude_attributes(dialog.to_model_hash, EXCLUDE_ATTRS)

          filename = Exports.safe_filename("#{dialog_hash[:dialog_type]}-#{dialog_hash[:name]}", options[:keep_spaces])
          File.write("#{export_dir}/#{filename}.yaml", dialog_hash.to_yaml)
        end
      end
    end
  end
end
