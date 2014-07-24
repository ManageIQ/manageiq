class WidgetImporter
  class Validator
    class NonYamlError < StandardError; end

    def determine_validity(import_file_upload)
      YAML.load(import_file_upload.uploaded_content)
    rescue Psych::SyntaxError
      raise NonYamlError
    end
  end
end
