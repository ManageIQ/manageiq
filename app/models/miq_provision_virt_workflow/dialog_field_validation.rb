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

  def validate_vm_name(field, values, dlg, fld, value)
    validate_length(field, values, dlg, fld, value)
  end

  def validate_memory_reservation(_field, values, dlg, fld, _value)
    allocated = get_value(values[:vm_memory]).to_i
    reserved  = get_value(values[:memory_reserve]).to_i
    if reserved > allocated
      _("%{description} Reservation is larger than VM Memory") % {:description => required_description(dlg, fld)}
    end
  end

  def validate_pxe_image_id(_field, _values, dlg, fld, _value)
    return nil unless supports_pxe?
    return nil unless get_pxe_image.nil?
    _("%{description} is required") % {:description => required_description(dlg, fld)}
  end

  def validate_pxe_server_id(_field, _values, dlg, fld, _value)
    return nil unless supports_pxe?
    return nil unless get_pxe_server.nil?
    _("%{description} is required") % {:description => required_description(dlg, fld)}
  end

  def validate_placement(field, values, dlg, fld, value)
    # check the :placement_auto flag, then make sure the field is not blank
    return nil unless value.blank?
    return nil if get_value(values[:placement_auto]) == true
    return nil unless get_value(values[field]).blank?
    _("%{description} is required") % {:description => required_description(dlg, fld)}
  end

  def validate_sysprep_upload(field, values, dlg, fld, value)
    return nil unless value.blank?
    return nil unless get_value(values[:sysprep_enabled]) == 'file'
    return nil unless get_value(values[field]).blank?
    _("%{description} is required") % {:description => required_description(dlg, fld)}
  end

  def validate_sysprep_field(field, values, dlg, fld, value)
    return nil unless value.blank?
    return nil unless get_value(values[:sysprep_enabled]) == 'fields'
    return nil unless get_value(values[field]).blank?
    _("%{description} is required") % {:description => required_description(dlg, fld)}
  end
end
