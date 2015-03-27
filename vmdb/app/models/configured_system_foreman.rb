class ConfiguredSystemForeman < ConfiguredSystem
  include ProviderObjectMixin

  belongs_to :configuration_location
  belongs_to :configuration_organization
  belongs_to :customization_script_medium
  belongs_to :customization_script_ptable

  def provider_object(connection = nil)
    (connection || connection_source.connect).host(manager_ref)
  end

  private

  def connection_source(options = {})
    options[:connection_source] || configuration_manager
  end
end
