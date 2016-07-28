class SysprepAutoLogonVisibilityService
  def determine_visibility(sysprep_auto_logon)
    field_names_to_hide = []
    field_names_to_show = []

    if sysprep_auto_logon == false
      field_names_to_hide += [:sysprep_auto_logon_count]
    else
      field_names_to_show += [:sysprep_auto_logon_count]
    end

    {:hide => field_names_to_hide, :show => field_names_to_show}
  end
end
