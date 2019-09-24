module VmMigrateWorkflow::DialogFieldValidation
  def validate_placement(field, values, dlg, fld, value)
    # check the :placement_auto flag, then make sure the field is not blank
    return nil unless value.blank?
    return nil unless get_value(values[field]).blank?
    "#{required_description(dlg, fld)} is required"
  end
end
