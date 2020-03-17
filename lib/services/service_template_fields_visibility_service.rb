class ServiceTemplateFieldsVisibilityService
  def determine_visibility(service_template_request)
    field_names_to_hide = []
    if service_template_request
      field_names_to_hide += %i[vm_description schedule_type schedule_time]
    end

    {:hide => field_names_to_hide}
  end
end
