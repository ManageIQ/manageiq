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
      dialog_field_attributes.delete("dialog_field_responders")
      resource_action = ResourceAction.new(resource_action_attributes)
      dialog_field = dialog_field_type_class.new(dialog_field_attributes.merge("resource_action" => resource_action))
      if dialog_field_attributes["type"] == "DialogFieldTagControl"
        set_category_for_tag_control(dialog_field, dialog_field_attributes)
      end
      dialog_field.save

      dialog_field
    elsif dialog_field_attributes["type"].nil?
      dialog_field_attributes.delete("dialog_field_responders")
      dialog_field_attributes.delete("resource_action")
      DialogField.create(dialog_field_attributes)
    else
      raise InvalidDialogFieldTypeError
    end
  end

  private

  def set_category_for_tag_control(dialog_field, dialog_field_attributes)
    dialog_field.category = adjust_category(dialog_field_attributes['options'])
  end

  def adjust_category(opts)
    return nil if opts[:category_description].nil?
    category = if opts[:category_id]
                 Category.find(opts[:category_id])
               elsif opts[:category_name]
                 Category.find_by_name(opts[:category_name])
               end
    category.try(:description) == opts[:category_description] ? category.try(:id).to_s : nil
  end
end
