class ConfiguredSystemForeman < ConfiguredSystem
  include ProviderObjectMixin

  def provider_object(connection = nil)
    (connection || raw_connect).host(manager_ref)
  end

  private

  def connection_source(options = {})
    options[:connection_source] || configuration_manager
  end
end
