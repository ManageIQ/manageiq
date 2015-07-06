class ResourceActionSerializer < Serializer
  EXCLUDED_ATTRIBUTES = %w(created_at updated_at id dialog_id resource_id)

  def serialize(resource_action)
    included_attributes(resource_action.attributes)
  end
end
