class DialogFieldImporter
  class InvalidDialogFieldTypeError < StandardError; end

  def import_field(dialog_field_attributes, export_version = DialogImportService::CURRENT_DIALOG_VERSION)
    if dialog_field_attributes["type"] == "DialogFieldDynamicList"
      dialog_field_attributes["type"] = "DialogFieldDropDownList"
      dialog_field_attributes["dynamic"] = true
    end

    if Gem::Version.new(export_version) < Gem::Version.new('5.11')
      dialog_field_attributes["load_values_on_init"] = if !dialog_field_attributes["show_refresh_button"]
                                                         # no refresh button, always true
                                                         true
                                                       elsif dialog_field_attributes["load_values_on_init"].nil?
                                                         # unspecified, default to true
                                                         true
                                                       else
                                                         !!dialog_field_attributes["load_values_on_init"]
                                                       end
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
      dialog_field.save!

      dialog_field
    elsif dialog_field_attributes["type"].nil?
      dialog_field_attributes.delete("dialog_field_responders")
      dialog_field_attributes.delete("resource_action")
      DialogField.create!(dialog_field_attributes)
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
    category = find_category(opts)
    category.try(:id).to_s if category.try(:description) == opts[:category_description]
  end

  def find_category(opts)
    if opts[:category_id]
      cat = Category.find_by(:id => opts[:category_id])
      return cat if cat.try(:name) == opts[:category_name]
    end
    Category.lookup_by_name(opts[:category_name])
  end
end
