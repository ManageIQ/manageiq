class SysprepCustomSpecVisibilityService
  def determine_visibility(sysprep_custom_spec)
    field_names_to_hide = []
    field_names_to_edit = []

    if sysprep_custom_spec
      field_names_to_edit += [:sysprep_spec_override]
    else
      field_names_to_hide += [:sysprep_spec_override]
    end

    {:hide => field_names_to_hide, :edit => field_names_to_edit}
  end
end
