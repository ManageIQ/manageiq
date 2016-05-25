class ManageIQ::Providers::Softlayer::CloudManager::ProvisionWorkflow < ::MiqProvisionCloudWorkflow
  def allowed_instance_types(_options = {})
    source = load_ar_obj(get_source_vm)
    ems = get_targets_for_ems(source, :cloud_filter, Flavor, 'flavors')
    ems.each_with_object({}) { |f, h| h[f.id] = display_name_for_name_description(f) }
  end

  def self.provider_model
    ManageIQ::Providers::Softlayer::CloudManager
  end

  private

  def dialog_name_from_automate(message = 'get_dialog_name')
    super(message, {'platform' => 'softlayer'})
  end
end
