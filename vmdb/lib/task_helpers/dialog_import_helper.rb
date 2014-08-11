require "dialog_import_service"

module TaskHelpers
  class DialogImportHelper
    def initialize(dialog_import_service = DialogImportService.new)
      @dialog_import_service = dialog_import_service
    end

    def import(filename)
      @dialog_import_service.import_from_file(filename) do |dialog|
        $log.info("Skipping importing of dialog with label #{dialog["label"]} as it already exists")
        Kernel.puts "Skipping dialog #{dialog["label"]} as it already exists"
      end
    end
  end
end
