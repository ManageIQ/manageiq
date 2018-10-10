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
    tenant = user_or_group.current_tenant

    if tenant.source_id
      ["(vms.template = true AND (vms.tenant_id = (?) AND vms.publicly_available = false OR vms.publicly_available = true))", tenant.id]
    else
      ["(vms.template = true AND (vms.tenant_id IN (?) OR vms.publicly_available = true))", template_tenant_ids] unless template_tenant_ids.empty?
    end
  end

  private

  def raise_created_event
    MiqEvent.raise_evm_event(self, "vm_template", :vm => self)
  end
end
