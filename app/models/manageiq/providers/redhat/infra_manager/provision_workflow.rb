class ManageIQ::Providers::Redhat::InfraManager::ProvisionWorkflow < MiqProvisionInfraWorkflow
  include CloudInitTemplateMixin

  def self.default_dialog_file
    'miq_provision_dialogs'
  end

  def self.provider_model
    ManageIQ::Providers::Redhat::InfraManager
  end

  def supports_pxe?
    get_value(@values[:provision_type]).to_s == 'pxe'
  end

  def supports_iso?
    get_value(@values[:provision_type]).to_s == 'iso'
  end

  def supports_native_clone?
    get_value(@values[:provision_type]).to_s == 'native_clone'
  end

  def supports_linked_clone?
    supports_native_clone? && get_value(@values[:linked_clone])
  end

  def supports_cloud_init?
    true
  end

  def allowed_provision_types(_options = {})
    {
      "pxe"          => "PXE",
      "iso"          => "ISO",
      "native_clone" => "Native Clone"
    }
  end

  def dialog_name_from_automate(message = 'get_dialog_name')
    super(message, {'platform' => 'redhat'})
  end

  def update_field_visibility
    super(:force_platform => 'linux')
  end

  def update_field_visibility_linked_clone(_options = {}, f)
    show_flag = supports_native_clone? ? :edit : :hide
    f[show_flag] << :linked_clone

    show_flag = supports_linked_clone? ? :hide : :edit
    f[show_flag] << :disk_format
  end

  def allowed_customization_templates(options = {})
    if supports_native_clone?
      return allowed_cloud_init_customization_templates(options)
    else
      return super(options)
    end
  end

  def allowed_datacenters(_options = {})
    super.slice(datacenter_by_vm.try(:id))
  end

  def datacenter_by_vm
    @datacenter_by_vm ||= begin
                            vm = resources_for_ui[:vm]
                            VmOrTemplate.find(vm.id).parent_datacenter if vm
                          end
  end

  def set_on_vm_id_changed
    @datacenter_by_vm = nil
    super
  end

  def allowed_hosts_obj(_options = {})
    super(:datacenter => datacenter_by_vm)
  end

  def allowed_storages(options = {})
    return [] if (src = resources_for_ui).blank?
    result = super

    if supports_linked_clone?
      s_id = load_ar_obj(src[:vm]).storage_id
      result = result.select { |s| s.id == s_id }
    end

    result.select { |s| s.storage_domain_type == "data" }
  end
end
