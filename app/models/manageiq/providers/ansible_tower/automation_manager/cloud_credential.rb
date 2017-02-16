class ManageIQ::Providers::AnsibleTower::AutomationManager::CloudCredential < ManageIQ::Providers::AnsibleTower::AutomationManager::Credential
  def self.credential_types
    subclasses.sort_by(&:name).each_with_object({}) do |subclass, credential_types|
      provider_name = subclass.name.demodulize.split('Credential').first
      credential_types[provider_name] = subclass.name
    end
  end
end
