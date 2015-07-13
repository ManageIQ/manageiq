class DialogTabSerializer < Serializer
  EXCLUDED_ATTRIBUTES = ["created_at", "dialog_id", "id", "updated_at"]

  def initialize(dialog_group_serializer = DialogGroupSerializer.new)
    @dialog_group_serializer = dialog_group_serializer
  end

  def serialize(dialog_tab)
    serialized_dialog_groups = serialize_dialog_groups(dialog_tab.dialog_groups)

    included_attributes(dialog_tab.attributes).merge("dialog_groups" => serialized_dialog_groups)
  end

  def serialize_dialog_groups(dialog_groups)
    dialog_groups.map do |dialog_group|
      @dialog_group_serializer.serialize(dialog_group)
    end
  end
end
