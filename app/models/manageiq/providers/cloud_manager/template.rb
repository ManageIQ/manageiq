class ManageIQ::Providers::CloudManager::Template < ::MiqTemplate
  default_value_for :cloud, true

  def self.eligible_for_provisioning
    super.where(:type => %w(ManageIQ::Providers::Amazon::CloudManager::Template
                            ManageIQ::Providers::Openstack::CloudManager::Template))
  end

  private

  def raise_created_event
    MiqEvent.raise_evm_event(self, "vm_template", :vm => self)
  end
end
