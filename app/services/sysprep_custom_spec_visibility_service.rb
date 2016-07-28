class SysprepCustomSpecVisibilityService
  def determine_visibility(sysprep_custom_spec)
    field_names_to_hide = []
    field_names_to_show = []

    if sysprep_custom_spec
      field_names_to_hide += [:sysprep_spec_override]
    else
      field_names_to_show += [:sysprep_spec_override]
    end

    {:hide => field_names_to_hide, :show => field_names_to_show}
  end
end
