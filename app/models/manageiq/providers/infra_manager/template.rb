class ManageIQ::Providers::InfraManager::Template < MiqTemplate
  default_value_for :cloud, false

  def self.eligible_for_provisioning
    super.where(:type => %w(ManageIQ::Providers::Redhat::InfraManager::Template ManageIQ::Providers::Vmware::InfraManager::Template TemplateMicrosoft))
  end

  private

  def raise_created_event
    MiqEvent.raise_evm_event(self, "vm_template", :vm => self, :host => host)
  end
end
