class DynamicDialogFieldValueProcessor
  def self.values_from_automate(dialog_field)
    self.new.values_from_automate(dialog_field)
  end

  def values_from_automate(dialog_field)
    dialog_values = {:dialog => dialog_field.dialog.try(:automate_values_hash)}
    workspace = dialog_field.resource_action.deliver_to_automate_from_dialog_field(
      dialog_values,
      dialog_field.dialog.try(:target_resource)
    )
    process_automate_values(dialog_field, workspace.root.attributes)
  rescue
    dialog_field.script_error_values
  end

  private

  def process_automate_values(dialog_field, workspace_attributes)
    %w(sort_by sort_order data_type default_value required).each do |key|
      dialog_field.send("#{key}=", workspace_attributes[key]) if workspace_attributes.key?(key)
    end

    dialog_field.normalize_automate_values(workspace_attributes["values"])
  end
end
