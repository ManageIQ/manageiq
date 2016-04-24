class DeploymentService
  def all_data
    {
      :provision              => possible_provision_providers,
      :providers              => possible_providers_and_vms_for_provisioning,
      :cloud_init_template_id => cloud_init_template_id,
    }.compact
  end

  def possible_provision_providers
    result = []
    providers = ExtManagementSystem.all.select do |m|
      m.instance_of?(ManageIQ::Providers::Amazon::CloudManager) || m.instance_of?(ManageIQ::Providers::Redhat::InfraManager)
    end
    providers.each do |provider|
      result << {:provider => provider, :templates => provider.miq_templates}
    end
    result
  end

  def possible_providers_and_vms_for_provisioning
    result = []
    providers = ExtManagementSystem.all.select do |m|
      m.type.to_s.include?("CloudManager") || m.type.to_s.include?("InfraManager")
    end
    providers.each do |provider|
      result << {:provider => provider, :vms => provider.vms.select do |vm| !vm.hardware.ipaddresses.empty? end}
    end
    result
  end

  def cloud_init_template_id
    ContainerDeployment.add_basic_root_template
    CustomizationTemplate.find_by_name("Basic root pass template").id
  end
end