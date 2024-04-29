module VmMigrateWorkflow::DialogFieldValidation
  def validate_placement(field, values, dlg, fld, value)
    # check the :placement_auto flag, then make sure the field is not blank
    return nil if value.present?
    return nil if get_value(values[field]).present?

    "#{required_description(dlg, fld)} is required"
  end
end
