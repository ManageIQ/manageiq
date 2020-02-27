class RequestTypeVisibilityService
  def determine_visibility(request_type)
    field_names_to_hide = []

    if %i[clone_to_vm clone_to_template].include?(request_type)
      field_names_to_hide += [:vm_filter]
      if request_type == :clone_to_template
        field_names_to_hide += [:vm_auto_start]
      end
    end

    {:hide => field_names_to_hide}
  end
end
