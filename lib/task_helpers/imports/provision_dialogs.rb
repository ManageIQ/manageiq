module TaskHelpers
  class Imports
    class ProvisionDialogs
      def import(options = {})
        return unless options[:source]

        glob = File.file?(options[:source]) ? options[:source] : "#{options[:source]}/*.yaml"
        Dir.glob(glob) do |fname|
          $log.info("Importing Provision Dialog from: #{fname}")

          dialog = YAML.load_file(fname)

          miq_dialog = MiqDialog.find_by(:name => dialog[:name], :dialog_type => dialog[:dialog_type])

          miq_dialog.nil? ? MiqDialog.create(dialog) : miq_dialog.update(dialog)
        end
      end
    end
  end
end
