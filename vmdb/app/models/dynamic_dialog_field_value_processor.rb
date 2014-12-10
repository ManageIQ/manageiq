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
    [[nil, "<Script error>"]]
  end

  private

  def process_automate_values(dialog_field, workspace_attributes)
    %w(sort_by sort_order data_type default_value required).each do |key|
      dialog_field.send("#{key}=", workspace_attributes[key]) if workspace_attributes.key?(key)
    end

    normalize_automate_values(dialog_field, workspace_attributes["values"])
  end

  def normalize_automate_values(dialog_field, ae_values)
    result = ae_values.to_a
    result.blank? ? dialog_field.initial_values : result
  end
end
