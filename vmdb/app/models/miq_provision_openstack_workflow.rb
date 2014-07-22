class MiqProvisionOpenstackWorkflow < MiqProvisionCloudWorkflow

  def allowed_instance_types(options={})
    source = load_ar_obj(get_source_vm)
    ems = source.try(:ext_management_system)

    return {} if ems.nil?
    ems.flavors.each_with_object({}) {|f, h| h[f.id] = display_name_for_name_description(f)}
  end

  def allowed_cloud_tenants(options={})
    source = load_ar_obj(get_source_vm)
    ems = source.try(:ext_management_system)

    return {} unless ems

    ems.cloud_tenants.each_with_object({}) { |f, h| h[f.id] = f.name }
  end

  private

  def dialog_name_from_automate(message = 'get_dialog_name')
    super(message, { 'platform' => 'openstack' })
  end

  def self.allowed_templates_vendor
    'openstack'
  end

end
