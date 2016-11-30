module ManageIQ::Providers::Azure::CloudManager::Vm::Operations
  extend ActiveSupport::Concern
  include_concern 'Power'

  def raw_destroy
    unless ext_management_system
      raise _("VM has no %{table}, unable to destroy VM") % {:table => ui_lookup(:table => "ext_management_systems")}
    end
    provider_service.delete_associated_resources(name, resource_group)
    update_attributes!(:raw_power_state => "Deleting")
  end
end
