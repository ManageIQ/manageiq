module TaskHelpers
  class DialogImportHelper
    def initialize(dialog_importer = DialogImporter.new)
      @dialog_importer = dialog_importer
    end

    def import(filename)
      @dialog_importer.import_from_file(filename) do |dialog|
        $log.info("Skipping importing of dialog with label #{dialog["label"]} as it already exists")
        Kernel.puts "Skipping dialog #{dialog["label"]} as it already exists"
      end
    end
  end
end
