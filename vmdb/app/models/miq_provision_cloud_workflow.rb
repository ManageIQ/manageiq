class MiqProvisionCloudWorkflow < MiqProvisionWorkflow
  include CloudInitTemplateMixin

  SUBCLASSES = %w{
    MiqProvisionAmazon
    MiqProvisionOpenstack
  }

  def allowed_availability_zones(options={})
    source = load_ar_obj(get_source_vm)
    ems = source.try(:ext_management_system)

    return {} if ems.nil?
    ems.availability_zones.available.each_with_object({}) {|az, h| h[az.id] = az.name}
  end

  def allowed_cloud_networks(options={})
    src = resources_for_ui
    return {} if src[:ems].nil?

    load_ar_obj(src[:ems]).cloud_networks.each_with_object({}) { |cn, hash| hash[cn.id] = cn.cidr.blank? ? cn.name : "#{cn.name} (#{cn.cidr})" }
  end

  def allowed_cloud_subnets(_options = {})
    src = resources_for_ui
    return {} if src[:cloud_network_id].nil?

    az_id = src[:availability_zone_id].to_i
    if (cn = CloudNetwork.where(:id => src[:cloud_network_id]).first)
      cn.cloud_subnets.each_with_object({}) do |cs, hash|
        next if !az_id.zero? && az_id != cs.availability_zone_id
        hash[cs.id] = "#{cs.name} (#{cs.cidr}) | #{cs.availability_zone.try(:name)}"
      end
    else
      {}
    end
  end

  def allowed_guest_access_key_pairs(options={})
    source = load_ar_obj(get_source_vm)
    ems = source.try(:ext_management_system)

    return {} if ems.nil?
    ems.key_pairs.each_with_object({}) {|kp, h| h[kp.id] = kp.name}
  end

  def allowed_security_groups(options={})
    source = load_ar_obj(get_source_vm)
    ems = source.try(:ext_management_system)

    return {} if ems.nil?
    ems.security_groups.each_with_object({}) {|sg, h| h[sg.id] = display_name_for_name_description(sg)}
  end

  def allowed_floating_ip_addresses(options={})
    source = load_ar_obj(get_source_vm)
    ems = source.try(:ext_management_system)

    return {} if ems.nil?
    ems.floating_ips.available.each_with_object({}) {|ip, h| h[ip.id] = ip.address}
  end

  def display_name_for_name_description(ci)
    ci.description.blank? ? ci.name : "#{ci.name}: #{ci.description}"
  end

  def supports_cloud_init?
    true
  end

  def set_or_default_hardware_field_values(vm)
  end

  def update_field_visibility()
    show_dialog(:customize, :show, "disabled")
    super(:force_platform=>'linux')
  end

  def show_customize_fields(fields, platform)
    return show_customize_fields_pxe(fields)
  end

  def allowed_customization_templates(options={})
    return allowed_cloud_init_customization_templates(options)
  end

  private

  # Run the relationship methods and perform set intersections on the returned values.
  # Optional starting set of results maybe passed in.
  def allowed_ci(ci, relats, filtered_ids=nil)
    return {} if (sources = resources_for_ui).blank?
    super(ci, relats, sources, filtered_ids)
  end

  def get_source_and_targets(refresh=false)
    return @target_resource if @target_resource && refresh==false
    result = super
    return result if result.blank?

    add_target(:placement_availability_zone, :availability_zone, AvailabilityZone, result)
    add_target(:cloud_network,               :cloud_network,     CloudNetwork,     result)
    add_target(:cloud_subnet,                :cloud_subnet,      CloudSubnet,      result)

    rails_logger('get_source_and_targets', 1)
    return @target_resource=result
  end

  def dialog_name_from_automate(message, extra_attrs)
    extra_attrs['platform_category'] = 'cloud'
    super(message, extra_attrs)
  end
end

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
MiqProvisionCloudWorkflow::SUBCLASSES.each { |c| require_dependency Rails.root.join("app", "models", "#{c.underscore}_workflow.rb").to_s }
