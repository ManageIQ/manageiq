class DialogFieldVisibilityService
  attr_accessor :auto_placement_visibility_service
  attr_accessor :number_of_vms_visibility_service
  attr_accessor :service_template_fields_visibility_service
  attr_accessor :network_visibility_service
  attr_accessor :sysprep_auto_logon_visibility_service
  attr_accessor :retirement_visibility_service
  attr_accessor :customize_fields_visibility_service
  attr_accessor :sysprep_custom_spec_visibility_service
  attr_accessor :request_type_visibility_service
  attr_accessor :pxe_iso_visibility_service
  attr_accessor :linked_clone_visibility_service

  def initialize(
    auto_placement_visibility_service = AutoPlacementVisibilityService.new,
    number_of_vms_visibility_service = NumberOfVmsVisibilityService.new,
    service_template_fields_visibility_service = ServiceTemplateFieldsVisibilityService.new,
    network_visibility_service = NetworkVisibilityService.new,
    sysprep_auto_logon_visibility_service = SysprepAutoLogonVisibilityService.new,
    retirement_visibility_service = RetirementVisibilityService.new,
    customize_fields_visibility_service = CustomizeFieldsVisibilityService.new,
    sysprep_custom_spec_visibility_service = SysprepCustomSpecVisibilityService.new,
    request_type_visibility_service = RequestTypeVisibilityService.new,
    pxe_iso_visibility_service = PxeIsoVisibilityService.new,
    linked_clone_visibility_service = LinkedCloneVisibilityService.new
  )
    @auto_placement_visibility_service = auto_placement_visibility_service
    @number_of_vms_visibility_service = number_of_vms_visibility_service
    @service_template_fields_visibility_service = service_template_fields_visibility_service
    @network_visibility_service = network_visibility_service
    @sysprep_auto_logon_visibility_service = sysprep_auto_logon_visibility_service
    @retirement_visibility_service = retirement_visibility_service
    @customize_fields_visibility_service = customize_fields_visibility_service
    @sysprep_custom_spec_visibility_service = sysprep_custom_spec_visibility_service
    @request_type_visibility_service = request_type_visibility_service
    @pxe_iso_visibility_service = pxe_iso_visibility_service
    @linked_clone_visibility_service = linked_clone_visibility_service
  end

  def set_visibility_for_field(visibility_hash, field_name, field)
    status = field[:display]
    status = :show if visibility_hash[:show].include?(field_name)
    status = :edit if visibility_hash[:edit].include?(field_name)
    status = :hide if visibility_hash[:hide].include?(field_name)

    field[:display] = field[:display_override].presence || status || :edit
  end

  def determine_visibility(options)
    @field_names_to_hide = []
    @field_names_to_edit = []
    @field_names_to_show = []

    add_to_visibility_arrays(service_template_fields_visibility_service, options[:service_template_request])
    add_to_visibility_arrays(auto_placement_visibility_service, options[:auto_placement_enabled])
    add_to_visibility_arrays(number_of_vms_visibility_service, options[:number_of_vms], options[:platform])

    add_to_visibility_arrays(
      network_visibility_service,
      options[:sysprep_enabled],
      options[:supports_pxe],
      options[:supports_iso],
      options[:addr_mode]
    )

    add_to_visibility_arrays(sysprep_auto_logon_visibility_service, options[:sysprep_auto_logon])
    add_to_visibility_arrays(retirement_visibility_service, options[:retirement])

    add_to_visibility_arrays(
      customize_fields_visibility_service,
      options[:platform],
      options[:supports_customization_template],
      options[:customize_fields_list]
    )

    add_to_visibility_arrays(sysprep_custom_spec_visibility_service, options[:sysprep_custom_spec])
    add_to_visibility_arrays(request_type_visibility_service, options[:request_type])
    add_to_visibility_arrays(pxe_iso_visibility_service, options[:supports_iso], options[:supports_pxe])
    add_to_visibility_arrays(
      linked_clone_visibility_service,
      options[:provision_type],
      options[:linked_clone],
      options[:snapshot_count]
    )

    @field_names_to_hide -= @field_names_to_hide & @field_names_to_edit
    @field_names_to_hide.uniq!
    @field_names_to_edit.uniq!

    {
      :hide => @field_names_to_hide.flatten,
      :edit => @field_names_to_edit.flatten,
      :show => @field_names_to_show.flatten
    }
  end

  private

  def add_to_visibility_arrays(visibility_service, *options)
    visibility_hash = visibility_service.determine_visibility(*options)
    @field_names_to_hide += visibility_hash[:hide]
    @field_names_to_edit += visibility_hash[:edit] if visibility_hash[:edit]
    @field_names_to_show += visibility_hash[:show] if visibility_hash[:show]
  end
end
