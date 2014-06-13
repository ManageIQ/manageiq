class DialogFieldSerializer < Serializer
  EXCLUDED_ATTRIBUTES = ["created_at", "dialog_group_id", "id", "updated_at"]

  def serialize(dialog_field)
    included_attributes(dialog_field.attributes)
  end
end
