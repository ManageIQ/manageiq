# These methods are available for dialog field validation, do not erase.
module MiqProvisionVirtWorkflow::DialogFieldValidation
  def default_require_sysprep_enabled(_field, _values, dlg, fld, value)
    if value.blank? || value == "disabled"
      _("%{description} is required") % {:description => required_description(dlg, fld)}
    end
  end

  def default_require_sysprep_custom_spec(_field, _values, dlg, fld, value)
    if value.blank? || value == "__VC__NONE__"
      _("%{description} is required") % {:description => required_description(dlg, fld)}
    end
  end
end
