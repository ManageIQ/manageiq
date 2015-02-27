class ConfiguredSystemForeman < ConfiguredSystem
  include ProviderObjectMixin

  def provider_object(connection = nil)
    (connection || connection_source.raw_connect).host(manager_ref)
  end

  # system is pending a build
  def pending?
    source.build_state == "pending"
  end

  private

  def connection_source(options = {})
    options[:connection_source] || configuration_manager
  end
end
