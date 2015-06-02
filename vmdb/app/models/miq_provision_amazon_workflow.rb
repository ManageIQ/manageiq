class MiqProvisionAmazonWorkflow < MiqProvisionCloudWorkflow
  def allowed_instance_types(options={})
    source = load_ar_obj(get_source_vm)
    ems = source.try(:ext_management_system)
    architecture = source.try(:hardware).try(:bitness)
    virtualization_type = source.try(:hardware).try(:virtualization_type)
    root_device_type = source.try(:hardware).try(:root_device_type)

    return {} if ems.nil?
    available = ems.flavors
    methods = ["supports_#{architecture}_bit?".to_sym, "supports_#{virtualization_type}?".to_sym]
    methods << :supports_instance_store? if root_device_type == 'instance_store'

    methods.each { |m| available = available.select(&m) if FlavorAmazon.method_defined?(m) }

    available.each_with_object({}) { |f, hash| hash[f.id] = display_name_for_name_description(f) }
  end

  def allowed_security_groups(options={})
    src = resources_for_ui
    return {} if src[:ems].nil?

    security_groups = if src[:cloud_network]
                        load_ar_obj(src[:cloud_network]).security_groups
                      else
                        load_ar_obj(src[:ems]).security_groups.non_cloud_network
    end

    security_groups.each_with_object({}) { |sg, hash| hash[sg.id] = display_name_for_name_description(sg) }
  end

  def allowed_floating_ip_addresses(options={})
    src = resources_for_ui
    return {} if src[:ems].nil?

    load_ar_obj(src[:ems]).floating_ips.available.each_with_object({}) do |ip, hash|
      next unless ip_available_for_selected_network?(ip, src)
      hash[ip.id] = ip.address
    end
  end

  def allowed_availability_zones(options={})
    allowed_ci(:availability_zones, [:cloud_network, :cloud_subnet, :security_group])
  end

  def validate_cloud_subnet(field, values, dlg, fld, value)
    return nil unless value.blank?
    return nil if get_value(values[:cloud_network]).to_i.zero?
    return nil unless get_value(values[field]).blank?
    return "#{required_description(dlg, fld)} is required"
  end

  private

  def dialog_name_from_automate(message = 'get_dialog_name')
    super(message, {'platform' => 'amazon'})
  end

  def self.allowed_templates_vendor
    'amazon'
  end

  def security_group_to_availability_zones(src)
    return nil unless src[:cloud_network]

    selected_group_ids = @values[:security_groups].to_a.compact
    return nil if selected_group_ids.blank?

    SecurityGroup.where(:id => selected_group_ids).each_with_object({}) do |sg, hash|
      next if sg.cloud_network.nil?
      sg.cloud_network.cloud_subnets.each do |cs|
        az = cs.availability_zone
        hash[az.id] = az.name
      end
    end
  end

  def cloud_network_to_availability_zones(src)
    return nil unless src[:cloud_network]

    load_ar_obj(src[:cloud_network]).cloud_subnets.each_with_object({}) do |cs, hash|
      az = cs.availability_zone
      hash[az.id] = az.name
    end
  end

  def cloud_subnet_to_availability_zones(src)
    availability_zones = if src[:cloud_subnet]
                           [load_ar_obj(src[:cloud_subnet]).availability_zone]
                         else
                           load_ar_obj(src[:ems]).availability_zones.available
                         end

    availability_zones.each_with_object({}) { |az, hash| hash[az.id] = az.name }
  end

  def ip_available_for_selected_network?(ip, src)
    ip.cloud_network_only? != src[:cloud_network_id].nil?
  end
end
