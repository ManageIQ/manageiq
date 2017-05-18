class DialogImportValidator
  class ImportNonYamlError < StandardError; end
  class InvalidDialogFieldTypeError < StandardError; end
  class ParsedNonDialogYamlError < StandardError; end
  class ParsedNonDialogError < StandardError; end

  def determine_validity(import_file_upload)
    potential_dialogs = YAML.load(import_file_upload.uploaded_content)
    check_dialogs_for_validity(potential_dialogs)
  rescue Psych::SyntaxError
    raise ImportNonYamlError
  end

  def determine_dialog_validity(dialog)
    raise ParsedNonDialogError unless dialog['dialog_tabs']
    check_dialog_tabs_for_validity(dialog['dialog_tabs'])
  rescue ParsedNonDialogYamlError
    raise ParsedNonDialogError, 'Not a valid dialog'
  end

  private

  def check_dialogs_for_validity(dialogs)
    dialogs.each do |dialog|
      raise ParsedNonDialogYamlError unless dialog["dialog_tabs"]
      check_dialog_tabs_for_validity(dialog["dialog_tabs"])
    end
  rescue TypeError
    raise ParsedNonDialogYamlError
  end

  def check_dialog_tabs_for_validity(dialog_tabs)
    dialog_tabs.each do |dialog_tab|
      raise ParsedNonDialogYamlError unless dialog_tab["dialog_groups"]
      check_dialog_groups_for_validity(dialog_tab["dialog_groups"])
    end
  end

  def check_dialog_groups_for_validity(dialog_groups)
    dialog_groups.each do |dialog_group|
      raise ParsedNonDialogYamlError unless dialog_group["dialog_fields"]
      check_dialog_fields_for_validity(dialog_group["dialog_fields"])
    end
  end

  def check_dialog_fields_for_validity(dialog_fields)
    dialog_fields.each do |dialog_field|
      unless valid_dialog_field_type?(dialog_field["type"])
        raise InvalidDialogFieldTypeError
      end
    end
  end

  def valid_dialog_field_type?(type)
    DialogField::DIALOG_FIELD_TYPES.include?(type) || type.nil? || type == "DialogFieldDynamicList"
  end
end
