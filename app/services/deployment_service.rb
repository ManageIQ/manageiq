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
      result << {:provider => provider, :templates => templates(provider.miq_templates)}
    end
    result
  end

  def templates(templates)
    result = []
    templates.each do |template|
      result << {
        :ui_cpu => template.cpu_total_cores,
        :ui_memo =>  template.mem_cpu,
        :name => template.name,
        :ems_id =>  template.ems_id,
        :id => template.id
      }
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