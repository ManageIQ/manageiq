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
                            ManageIQ::Providers::Openstack::CloudManager::VolumeTemplate
                            ManageIQ::Providers::Openstack::CloudManager::VolumeSnapshotTemplate))
  end

  def self.tenant_id_clause(user_or_group)
    template_tenant_ids = MiqTemplate.accessible_tenant_ids(user_or_group, Rbac.accessible_tenant_ids_strategy(self))
    return if template_tenant_ids.empty?

    ["(vms.template = true AND (vms.tenant_id IN (?) OR vms.publicly_available = true))", template_tenant_ids]
  end

  private

  def raise_created_event
    MiqEvent.raise_evm_event(self, "vm_template", :vm => self)
  end
end
