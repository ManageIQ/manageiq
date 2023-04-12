class DynamicDialogFieldValueProcessor
  def self.values_from_automate(dialog_field)
    new.values_from_automate(dialog_field)
  end

  def values_from_automate(dialog_field)
    dialog_values = {:dialog => dialog_field.dialog.try(:automate_values_hash)}
    attributes = dialog_field.resource_action.deliver(
      dialog_values,
      dialog_field.dialog.try(:target_resource),
      User.current_user
    )

    dialog_field.normalize_automate_values(attributes)
  rescue => e
    $log.log_backtrace(e)

    dialog_field.script_error_values
  end
end
