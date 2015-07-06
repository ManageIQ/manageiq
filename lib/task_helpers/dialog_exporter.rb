module TaskHelpers
  class DialogExporter
    def initialize(dialog_yaml_serializer = DialogYamlSerializer.new)
      @dialog_yaml_serializer = dialog_yaml_serializer
    end

    def export(filename)
      dialog_yaml = @dialog_yaml_serializer.serialize(Dialog.all)

      File.write(filename, dialog_yaml)
    end
  end
end
