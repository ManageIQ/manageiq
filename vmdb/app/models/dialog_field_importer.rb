class DialogFieldImporter
  class InvalidDialogFieldTypeError < StandardError; end

  def import_field(dialog_field_attributes)
    if DialogField::DIALOG_FIELD_TYPES.include?(dialog_field_attributes["type"])
      dialog_field_type_class = dialog_field_attributes["type"].constantize
      dialog_field = dialog_field_type_class.new(dialog_field_attributes)
      dialog_field.save

      dialog_field
    elsif dialog_field_attributes["type"].nil?
      DialogField.create(dialog_field_attributes)
    else
      raise InvalidDialogFieldTypeError
    end
  end
end
