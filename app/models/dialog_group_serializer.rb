class DialogGroupSerializer < Serializer
  EXCLUDED_ATTRIBUTES = ["created_at", "dialog_tab_id", "id", "updated_at"]

  def initialize(dialog_field_serializer = DialogFieldSerializer.new)
    @dialog_field_serializer = dialog_field_serializer
  end

  def serialize(dialog_group)
    serialized_dialog_fields = serialize_dialog_fields(dialog_group.dialog_fields)

    included_attributes(dialog_group.attributes).merge("dialog_fields" => serialized_dialog_fields)
  end

  private

  def serialize_dialog_fields(dialog_fields)
    dialog_fields.map do |dialog_field|
      @dialog_field_serializer.serialize(dialog_field)
    end
  end
end
