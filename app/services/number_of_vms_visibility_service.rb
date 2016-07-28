class NumberOfVmsVisibilityService
  def determine_visibility(number_of_vms, platform)
    field_names_to_hide = []
    field_names_to_show = []

    if number_of_vms > 1
      field_names_to_hide += [:sysprep_computer_name, :linux_host_name]
      field_names_to_show += [:ip_addr]
    else
      field_names_to_hide += [:ip_addr]

      if platform == "linux"
        field_names_to_show += [:linux_host_name]
        field_names_to_hide += [:sysprep_computer_name]
      else
        field_names_to_show += [:sysprep_computer_name]
        field_names_to_hide += [:linux_host_name]
      end
    end

    {:hide => field_names_to_hide, :show => field_names_to_show}
  end
end
