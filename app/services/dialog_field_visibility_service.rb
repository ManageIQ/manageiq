class DialogFieldVisibilityService
  def initialize(
    auto_placement_visibility_service = AutoPlacementVisibilityService.new,
    number_of_vms_visibility_service = NumberOfVmsVisibilityService.new,
    service_template_fields_visibility_service = ServiceTemplateFieldsVisibilityService.new,
    network_visibility_service = NetworkVisibilityService.new,
    sysprep_auto_logon_visibility_service = SysprepAutoLogonVisibilityService.new,
    retirement_visibility_service = RetirementVisibilityService.new,
    customize_fields_visibility_service = CustomizeFieldsVisibilityService.new
  )
    @auto_placement_visibility_service = auto_placement_visibility_service
    @number_of_vms_visibility_service = number_of_vms_visibility_service
    @service_template_fields_visibility_service = service_template_fields_visibility_service
    @network_visibility_service = network_visibility_service
    @sysprep_auto_logon_visibility_service = sysprep_auto_logon_visibility_service
    @retirement_visibility_service = retirement_visibility_service
    @customize_fields_visibility_service = customize_fields_visibility_service
  end

  def set_hidden_fields(field_names_to_hide, fields)
    set_fields_display_status(fields, field_names_to_hide, :hide)
  end

  def set_shown_fields(field_names_to_show, fields)
    set_fields_display_status(fields, field_names_to_show, :edit)
  end

  def determine_visibility(options)
    field_names_to_hide = []
    field_names_to_show = []

    visibility_hash = @service_template_fields_visibility_service.determine_visibility(options[:service_template_request])
    field_names_to_hide += visibility_hash[:hide]

    visibility_hash = @auto_placement_visibility_service.determine_visibility(options[:auto_placement_enabled])
    field_names_to_hide += visibility_hash[:hide]
    field_names_to_show += visibility_hash[:show]

    visibility_hash = @number_of_vms_visibility_service.determine_visibility(options[:number_of_vms], options[:platform])
    field_names_to_hide += visibility_hash[:hide]
    field_names_to_show += visibility_hash[:show]

    visibility_hash = @network_visibility_service.determine_visibility(options[:sysprep_enabled], options[:supports_pxe], options[:supports_iso], options[:addr_mode])
    field_names_to_hide += visibility_hash[:hide]
    field_names_to_show += visibility_hash[:show]

    visibility_hash = @sysprep_auto_logon_visibility_service.determine_visibility(options[:sysprep_auto_logon])
    field_names_to_hide += visibility_hash[:hide]
    field_names_to_show += visibility_hash[:show]

    visibility_hash = @retirement_visibility_service.determine_visibility(options[:retirement])
    field_names_to_hide += visibility_hash[:hide]
    field_names_to_show += visibility_hash[:show]

    visibility_hash = @customize_fields_visibility_service.determine_visibility(options[:platform], options[:supports_customization_template], options[:customize_fields_list])
    field_names_to_hide += visibility_hash[:hide]
    field_names_to_show += visibility_hash[:show]

    field_names_to_hide -= field_names_to_hide & field_names_to_show
    field_names_to_hide.uniq!
    field_names_to_show.uniq!
    {:hide => field_names_to_hide.flatten, :edit => field_names_to_show.flatten}
  end

  private

  def set_fields_display_status(fields, field_name_list, status)
    fields.each do |field|
      if field_name_list.include?(field[:name])
        field[:display] = field[:display_override].presence || status
      end
    end
  end
end
