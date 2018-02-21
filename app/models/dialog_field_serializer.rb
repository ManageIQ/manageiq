class DialogFieldSerializer < Serializer
  EXCLUDED_ATTRIBUTES = ["created_at", "dialog_group_id", "id", "updated_at"]

  def self.serialize(dialog_field, all_attributes = false)
    new.serialize(dialog_field, all_attributes)
  end

  def initialize(resource_action_serializer = ResourceActionSerializer.new)
    @resource_action_serializer = resource_action_serializer
  end

  def serialize(dialog_field, all_attributes = false)
    serialized_resource_action = @resource_action_serializer.serialize(dialog_field.resource_action)
    extra_attributes = {
      "resource_action"         => serialized_resource_action,
      "dialog_field_responders" => dialog_field.dialog_field_responders.map(&:name)
    }

    if dialog_field.dynamic?
      dynamic_values = dialog_field.trigger_automate_value_updates
      extra_attributes["values"] = dynamic_values
    end

    if dialog_field.type == "DialogFieldTagControl"
      category = Category.find_by(:id => dialog_field.category)
      if category
        dialog_field.options.merge!(:category_name => category.name, :category_description => category.description)
        dialog_field.options[:force_single_value] = dialog_field.options[:force_single_value] || category.single_value
      end
    end
    included_attributes(dialog_field.as_json(:methods => [:type, :values]), all_attributes).merge(extra_attributes)
  end
end
