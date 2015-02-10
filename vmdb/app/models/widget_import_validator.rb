class WidgetImportValidator
  class InvalidWidgetYamlError < StandardError; end
  class NonYamlError < StandardError; end

  def determine_validity(import_file_upload)
    widgets = YAML.load(import_file_upload.uploaded_content)

    raise InvalidWidgetYamlError unless widgets.all? { |widget| widget["MiqWidget"] }
  rescue Psych::SyntaxError
    raise NonYamlError
  end
end
