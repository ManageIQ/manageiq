class WidgetImportValidator
  class InvalidWidgetYamlError < StandardError; end
  class NonYamlError < StandardError; end

  def determine_validity(import_file_upload)
    widgets = YAML.load(import_file_upload.uploaded_content)

    raise InvalidWidgetYamlError unless widgets.all? do |widget_or_key, _|
      widget_or_key["MiqWidget"] || widget_or_key == "MiqWidget"
    end
  rescue Psych::SyntaxError
    raise NonYamlError
  rescue
    raise InvalidWidgetYamlError
  end
end
