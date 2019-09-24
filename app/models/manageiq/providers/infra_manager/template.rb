class ManageIQ::Providers::InfraManager::Template < MiqTemplate
  default_value_for :cloud, false

  def self.eligible_for_provisioning
    super.where(:type => %w(ManageIQ::Providers::Redhat::InfraManager::Template
                            ManageIQ::Providers::Vmware::InfraManager::Template
                            ManageIQ::Providers::Microsoft::InfraManager::Template
                            ManageIQ::Providers::Kubevirt::InfraManager::Template))
  end

  def self.display_name(number = 1)
    n_('Template', 'Templates', number)
  end

  private

  def raise_created_event
    MiqEvent.raise_evm_event(self, "vm_template", :vm => self, :host => host)
  end
end
