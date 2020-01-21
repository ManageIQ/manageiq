class DialogSerializer < Serializer
  EXCLUDED_ATTRIBUTES = %w(created_at id updated_at)

  def initialize(dialog_tab_serializer = DialogTabSerializer.new)
    @dialog_tab_serializer = dialog_tab_serializer
  end

  def serialize(dialogs, all_attributes = false)
    serialize_dialogs(dialogs, all_attributes)
  end

  private

  def serialize_dialog_tabs(dialog_tabs, all_attributes)
    dialog_tabs.map do |dialog_tab|
      @dialog_tab_serializer.serialize(dialog_tab, all_attributes)
    end
  end

  def serialize_dialogs(dialogs, all_attributes)
    dialogs.map do |dialog|
      serialized_dialog_tabs = serialize_dialog_tabs(dialog.dialog_tabs, all_attributes)
      included_attributes(dialog.attributes, all_attributes).merge("dialog_tabs" => serialized_dialog_tabs, 'export_version' => DialogImportService::CURRENT_DIALOG_VERSION)
    end
  end
end
