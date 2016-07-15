class ManageIQ::Providers::Openstack::InfraManager::Template < ManageIQ::Providers::InfraManager::Template
  belongs_to :cloud_tenant
  include SupportsFeatureMixin

  supports :smartstate_analysis do
    if self.archived?
      unsupported_reason_add(:smartstate_analysis, nil)
    elsif self.orphaned?
      unsupported_reason_add(:smartstate_analysis, _("Smartstate Analysis cannot be performed on orphaned #{self.class.model_suffix} VM."))
    end
  end

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.images.get(ems_ref)
  end

  def has_active_proxy?
    true
  end

  def has_proxy?
    true
  end
end
