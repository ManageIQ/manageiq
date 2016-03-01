class ManageIQ::Providers::Openstack::CloudManager::ProvisionWorkflow < ::MiqProvisionCloudWorkflow
  def allowed_instance_types(_options = {})
    source                  = load_ar_obj(get_source_vm)
    flavors                 = get_targets_for_ems(source, :cloud_filter, Flavor, 'flavors')
    return {} if flavors.blank?
    minimum_disk_required   = [source.hardware.size_on_disk, source.hardware.disk_size_minimum.to_i].max
    minimum_memory_required = source.hardware.memory_mb_minimum.to_i * 1.megabyte
    flavors.each_with_object({}) do |flavor, h|
      next if flavor.root_disk_size <= minimum_disk_required
      next if flavor.memory         <= minimum_memory_required
      h[flavor.id] = display_name_for_name_description(flavor)
    end
  end

  def allowed_cloud_tenants(_options = {})
    source = load_ar_obj(get_source_vm)
    ems = get_targets_for_ems(source, :cloud_filter, CloudTenant, 'cloud_tenants')
    ems.each_with_object({}) { |f, h| h[f.id] = f.name }
  end

  def validate_cloud_network(field, values, dlg, fld, value)
    return nil if allowed_cloud_networks.length <= 1
    validate_placement(field, values, dlg, fld, value)
  end

  private

  def dialog_name_from_automate(message = 'get_dialog_name')
    super(message, {'platform' => 'openstack'})
  end

  def self.provider_model
    ManageIQ::Providers::Openstack::CloudManager
  end
end
