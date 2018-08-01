module TaskHelpers
  class Exports
    class ProvisionDialogs
      def export(options = {})
        export_dir = options[:directory]

        dialogs = options[:all] ? MiqDialog.all : MiqDialog.where(:default => [false, nil])

        dialogs.order(:id).to_a.collect! do |dialog|
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
