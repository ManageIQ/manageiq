class ManageIQ::Providers::CloudManager::Template < ::MiqTemplate
  default_value_for :cloud, true

  virtual_column :image?, :type => :boolean

  def image?
    genealogy_parent.nil?
  end

  def snapshot?
    !genealogy_parent.nil?
  end

  def self.eligible_for_provisioning
    super.where(:type => %w(ManageIQ::Providers::Amazon::CloudManager::Template
                            ManageIQ::Providers::Openstack::CloudManager::Template
                            ManageIQ::Providers::Azure::CloudManager::Template
                            ManageIQ::Providers::Google::CloudManager::Template
                            ManageIQ::Providers::Openstack::CloudManager::VolumeTemplate))
  end

  private

  def raise_created_event
    MiqEvent.raise_evm_event(self, "vm_template", :vm => self)
  end
end
