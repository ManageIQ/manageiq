class DialogYamlSerializer < Serializer
  EXCLUDED_ATTRIBUTES = ["created_at", "id", "updated_at"]

  def initialize(dialog_tab_serializer = DialogTabSerializer.new)
    @dialog_tab_serializer = dialog_tab_serializer
  end

  def serialize(dialogs)
    serialize_dialogs(dialogs).to_yaml
  end

  private

  def serialize_dialog_tabs(dialog_tabs)
    dialog_tabs.map do |dialog_tab|
      @dialog_tab_serializer.serialize(dialog_tab)
    end
  end

  def serialize_dialogs(dialogs)
    dialogs.map do |dialog|
      serialized_dialog_tabs = serialize_dialog_tabs(dialog.dialog_tabs)

      included_attributes(dialog.attributes).merge("dialog_tabs" => serialized_dialog_tabs)
    end
  end
end
