class NumberOfVmsVisibilityService
  def determine_visibility(number_of_vms, platform)
    field_names_to_hide = []
    field_names_to_edit = []

    if number_of_vms > 1
      field_names_to_hide += %i[sysprep_computer_name linux_host_name floating_ip_address]
      field_names_to_edit += [:ip_addr]
    else
      field_names_to_hide += [:ip_addr]
      field_names_to_edit += [:floating_ip_address]

      if platform == "linux"
        field_names_to_edit += [:linux_host_name]
        field_names_to_hide += [:sysprep_computer_name]
      else
        field_names_to_edit += [:sysprep_computer_name]
        field_names_to_hide += [:linux_host_name]
      end
    end

    {:hide => field_names_to_hide, :edit => field_names_to_edit}
  end
end
