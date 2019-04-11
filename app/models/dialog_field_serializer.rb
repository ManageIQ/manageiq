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
      key_to_update = dialog_field.kind_of?(DialogFieldSortedItem) ? "values" : "default_value"

      extra_attributes[key_to_update] = dialog_field.extract_dynamic_values
    end

    if dialog_field.type == "DialogFieldTagControl"
      category = Category.find_by(:id => dialog_field.category)
      if category
        dialog_field.options.merge!(:category_name => category.name, :category_description => category.description)
        dialog_field.options[:force_single_value] = dialog_field.options[:force_single_value] || category.single_value
      end
    end
    json_options = dialog_field.dynamic? ? {:methods => [:type], :except => [:values]} : {:methods => %i(type values)}
    included_attributes(dialog_field.as_json(json_options), all_attributes).merge(extra_attributes)
  end
end
