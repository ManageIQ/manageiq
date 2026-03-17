class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::ProvisionWorkflow < ManageIQ::Providers::AutomationManager::ProvisionWorkflow
  def self.default_dialog_file
    "miq_provision_configuration_script_embedded_ansible_dialogs".freeze
  end

  def dialog_name_from_automate(message = 'get_dialog_name', extra_attrs = {})
    extra_attrs['platform'] ||= 'embedded_ansible'
    super
  end

  def allowed_configuration_scripts(*_args)
    self.class.module_parent::ConfigurationScript.all.map do |cs|
      build_ci_hash_struct(cs, %w[name description manager_name])
    end
  end

  def allowed_machine_credentials(*_args)
    self.class.module_parent::MachineCredential.all.to_h do |mc|
      [mc.id, mc.name]
    end
  end

  def allowed_vault_credentials(*_args)
    self.class.module_parent::VaultCredential.all.to_h do |vc|
      [vc.id, vc.name]
    end
  end

  def allowed_cloud_credential_types(*_args)
    # If a cloud credential is selected then pre-populate the Cloud Type
    cloud_credential_id = get_value(values[:cloud_credential_id])
    if cloud_credential_id && cloud_credential_id != 0 # TODO: Why is <None> = 0 ??
      # TODO why does self.class.module_parent::CloudCredential.find(id) not work?
      cloud_credential = ::Authentication.find(cloud_credential_id)
      {cloud_credential.class.to_s => cloud_credential.class::API_OPTIONS[:label]}
    else
      self.class.module_parent::CloudCredential.descendants.to_h do |klass|
       [klass.to_s, klass::API_OPTIONS[:label]]
     end
    end
  end

  def allowed_cloud_credentials(*_args)
    klass   = get_value(values[:cloud_credential_type])&.safe_constantize
    klass ||= self.class.module_parent::CloudCredential
    klass.all.to_h do |cc|
      [cc.id, "#{cc.name} - #{cc.type}"]
    end
  end
end
