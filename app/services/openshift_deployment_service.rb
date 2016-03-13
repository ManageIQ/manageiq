class OpenshiftDeploymentService
  def all_data
    {
      :providers              => possible_providers_and_vms_for_provisioning,
      :cloud_init_template_id => get_cloud_init_template_id,
      :supported_types        => get_deployment_types
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

  def get_cloud_init_template_id
    add_basic_root_template
    CustomizationTemplate.find_by_name("Basic root pass template").id
  end

  def add_basic_root_template
    unless CustomizationTemplate.find_by_name("Basic root pass template2")
      options = {:name              => "Basic root pass template",
                 :description       => "This template takes use of rootpassword defined in the UI",
                 :script            => "#cloud-config\nchpasswd:\n  list: |\n    root:<%= MiqPassword.decrypt(evm[:root_password]) %>\n  expire: False",
                 :type              => "CustomizationTemplateCloudInit",
                 :system            => true,
                 :pxe_image_type_id => PxeImageType.first.id}
      CustomizationTemplate.new(options).save
    end
  end

  def get_deployment_types
    Deployment.get_supported_types
  end
end
