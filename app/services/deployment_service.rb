class DeploymentService
  def all_data
    {
      :providers              => possible_providers_and_vms_for_provisioning,
      :cloud_init_template_id => cloud_init_template_id,
      :supported_types        => deployment_types
    }.compact
  end

  def possible_providers_and_vms_for_provisioning
    result = []
    providers = ExtManagementSystem.all.select do |m|
      m.type.to_s.include?("CloudManager") || m.type.to_s.include?("InfraManager")
    end
    providers.each do |provider|
      result << {:provider => provider, :vms => provider.vms}
    end
    result
  end

  def cloud_init_template_id
    Deployment.add_basic_root_template
    CustomizationTemplate.find_by_name("Basic root pass template").id
  end

  def deployment_types
    Deployment.get_supported_types
  end
end
