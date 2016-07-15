class ManageIQ::Providers::Google::CloudManager::Template < ManageIQ::Providers::CloudManager::Template

  include SupportsFeatureMixin

  supports_not :smartstate_analysis, :reason => "Smartstate Analysis is not available for VM or Template"

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.images[ems_ref]
  end
end
