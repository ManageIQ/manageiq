module TaskHelpers
  class Exports
    class ServiceDialogs
      def export(options = {})
        export_dir = options[:directory]

        dialogs = DialogSerializer.new.serialize(Dialog.order(:id).all)

        dialogs.each do |dialog|
          fname = Exports.safe_filename(dialog['label'], options[:keep_spaces])
          File.write("#{export_dir}/#{fname}.yaml", [dialog].to_yaml)
        end
      end
    end
  end
end
