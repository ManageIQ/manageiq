class DialogFieldSerializer < Serializer
  EXCLUDED_ATTRIBUTES = ["created_at", "dialog_group_id", "id", "updated_at"]

  def initialize(resource_action_serializer = ResourceActionSerializer.new)
    @resource_action_serializer = resource_action_serializer
  end

  def serialize(dialog_field)
    serialized_resource_action = @resource_action_serializer.serialize(dialog_field.resource_action)

    included_attributes(dialog_field.attributes).merge("resource_action" => serialized_resource_action)
  end
end
