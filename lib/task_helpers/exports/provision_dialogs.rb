module TaskHelpers
  class Exports
    class ProvisionDialogs
      def export(options = {})
        export_dir = options[:directory]

        dialogs = options[:all] ? MiqDialog.order(:id).all : MiqDialog.order(:id).where(:default => [false, nil])

        dialogs = dialogs.collect do |dialog|
          Exports.exclude_attributes(dialog.to_model_hash, %i(file_mtime created_at updated_at id class))
        end

        dialogs.each do |dialog|
          $log.info("Exporting Provision Dialog: #{dialog[:name]} (#{dialog[:description]})")

          fname = Exports.safe_filename("#{dialog[:dialog_type]}-#{dialog[:name]}", options[:keep_spaces])
          File.write("#{export_dir}/#{fname}.yaml", dialog.to_yaml)
        end
      end
    end
  end
end
