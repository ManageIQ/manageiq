class SysprepAutoLogonVisibilityService
  def determine_visibility(sysprep_auto_logon)
    field_names_to_hide = []
    field_names_to_edit = []

    if sysprep_auto_logon == false
      field_names_to_hide += [:sysprep_auto_logon_count]
    else
      field_names_to_edit += [:sysprep_auto_logon_count]
    end

    {:hide => field_names_to_hide, :edit => field_names_to_edit}
  end
end
