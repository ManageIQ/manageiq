class DialogFieldImporter
  class InvalidDialogFieldTypeError < StandardError; end

  def import_field(dialog_field_attributes)
    if dialog_field_attributes["type"] == "DialogFieldDynamicList"
      dialog_field_attributes["type"] = "DialogFieldDropDownList"
      dialog_field_attributes["dynamic"] = true
    end

    if DialogField::DIALOG_FIELD_TYPES.include?(dialog_field_attributes["type"])
      dialog_field_type_class = dialog_field_attributes["type"].constantize
      resource_action_attributes = dialog_field_attributes.delete("resource_action")
      resource_action = ResourceAction.new(resource_action_attributes)
      dialog_field = dialog_field_type_class.new(dialog_field_attributes.merge("resource_action" => resource_action))
      if dialog_field_attributes["type"] == "DialogFieldTagControl"
        dialog_field_attributes["options"].delete(:category_id)
        category_name = dialog_field_attributes["options"][:category_name]
        category_description = dialog_field_attributes["options"][:category_description]
        category = Category.find_by_name(category_name)
        dialog_field.category = category.try(:description) == category_description ? category.id.to_s : nil
      end
      dialog_field.save

      dialog_field
    elsif dialog_field_attributes["type"].nil?
      dialog_field_attributes.delete("resource_action")
      DialogField.create(dialog_field_attributes)
    else
      raise InvalidDialogFieldTypeError
    end
  end
end
