class ManageIQ::Providers::CloudManager::ProvisionWorkflow < ::MiqProvisionVirtWorkflow
  include_concern "DialogFieldValidation"
  include CloudInitTemplateMixin

  def allowed_availability_zones(_options = {})
    source = load_ar_obj(get_source_vm)
    targets = get_targets_for_ems(source, :cloud_filter, AvailabilityZone, 'availability_zones.available')
    targets.each_with_object({}) { |az, h| h[az.id] = az.name }
  end

  def allowed_cloud_networks(_options = {})
    return {} unless (src_obj = provider_or_tenant_object)

    src_obj.all_cloud_networks.each_with_object({}) do |cn, hash|
      hash[cn.id] = cn.cidr.blank? ? cn.name : "#{cn.name} (#{cn.cidr})"
    end
  end

  def allowed_cloud_subnets(_options = {})
    src = resources_for_ui
    return {} if src[:cloud_network_id].nil?

    az_id = src[:availability_zone_id].to_i
    if (cn = CloudNetwork.find_by(:id => src[:cloud_network_id]))
      cn.cloud_subnets.each_with_object({}) do |cs, hash|
        next if !az_id.zero? && az_id != cs.availability_zone_id
        hash[cs.id] = "#{cs.name} (#{cs.cidr}) | #{cs.availability_zone.try(:name)}"
      end
    else
      {}
    end
  end

  def allowed_guest_access_key_pairs(_options = {})
    source = load_ar_obj(get_source_vm)
    ems = source.try(:ext_management_system)

    return {} if ems.nil?
    ems.key_pairs.each_with_object({}) { |kp, h| h[kp.id] = kp.name }
  end

  def allowed_security_groups(_options = {})
    return {} unless (src = provider_or_tenant_object)

    src_obj = get_targets_for_source(src, :cloud_filter, SecurityGroup, 'security_groups')

    src_obj.each_with_object({}) do |sg, h|
      h[sg.id] = display_name_for_name_description(sg)
    end
  end

  def allowed_floating_ip_addresses(_options = {})
    return {} unless (src_obj = provider_or_tenant_object)

    src_obj.floating_ips.available.each_with_object({}) do |ip, h|
      h[ip.id] = ip.address
    end
  end

  def display_name_for_name_description(ci)
    ci.description.blank? ? ci.name : "#{ci.name}: #{ci.description}"
  end

  def supports_cloud_init?
    true
  end

  def set_or_default_hardware_field_values(_vm)
  end

  def update_field_visibility
    show_dialog(:customize, :show, "enabled")
    super(:force_platform => 'linux')
  end

  def show_customize_fields(fields, _platform)
    show_customize_fields_pxe(fields)
  end

  def allowed_customization_templates(options = {})
    allowed_cloud_init_customization_templates(options)
  end

  private

  # Run the relationship methods and perform set intersections on the returned values.
  # Optional starting set of results maybe passed in.
  def allowed_ci(ci, relats, filtered_ids = nil)
    return {} if (sources = resources_for_ui).blank?
    super(ci, relats, sources, filtered_ids)
  end

  def get_source_and_targets(refresh = false)
    return @target_resource if @target_resource && refresh == false
    result = super
    return result if result.blank?

    add_target(:placement_availability_zone, :availability_zone, AvailabilityZone, result)
    add_target(:cloud_network,               :cloud_network,     CloudNetwork,     result)
    add_target(:cloud_subnet,                :cloud_subnet,      CloudSubnet,      result)
    add_target(:cloud_tenant,                :cloud_tenant,      CloudTenant,      result)

    rails_logger('get_source_and_targets', 1)
    @target_resource = result
  end

  def get_targets_for_source(src, filter_name, klass, relats)
    process_filter(filter_name, klass, src.deep_send(relats))
  end

  def get_targets_for_ems(src, filter_name, klass, relats)
    ems = src.try(:ext_management_system)

    return {} if ems.nil?
    process_filter(filter_name, klass, ems.deep_send(relats))
  end

  def dialog_name_from_automate(message, extra_attrs)
    extra_attrs['platform_category'] = 'cloud'
    super(message, extra_attrs)
  end

  def provider_or_tenant_object
    src = resources_for_ui
    return nil if src[:ems].nil?
    obj = src[:cloud_tenant] || src[:ems]
    load_ar_obj(obj)
  end
end
