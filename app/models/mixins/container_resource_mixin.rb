# ContainerResourceMixin provides capabilities to container
# resources.
module ContainerResourceMixin
  extend ActiveSupport::Concern
  include ManageIQ::Providers::Kubernetes::ContainerManager::EntitiesMapping

  def spec
    resource = provider_definition
    unless resource[:spec].nil?
      return resource[:spec]
    end
    nil
  end

  def spec=(value)
    resource = provider_definition
    unless resource[:spec].nil?
      resource[:spec] = value
      response = update_in_provider(resource)
      return response
    end
    nil
  end

  def annotations(annotation = nil)
    resource = provider_definition
    if annotation.nil?
      return resource[:metadata][:annotations]
    end
    resource[:metadata][:annotations][annotation.to_sym]
  end

  # Provides the name of the enclosing namesapce
  def namespace
    container_project.name
  rescue NameError
    nil
  end

  def delete_from_provider
    method = "delete_#{entity_by_resource(self.class.name)}"
    api_version = container_project.ext_management_system.api_version
    client = container_project.ext_management_system.connect_client(api_version, method)
    response = client.send(method, name, namespace)
  rescue KubeException => e
    if e.error_code == 404
      return nil
    end
    raise
  else
    response
  end

  def tidy_provider_definition
    resource = provider_definition
    resource[:metadata].delete(:selfLink)
    resource[:metadata].delete(:uid)
    resource[:metadata].delete(:resourceVersion)
    resource[:metadata].delete(:creationTimestamp)
    resource
  end

  private

  def provider_definition
    method = "get_#{entity_by_resource(self.class.name)}"
    api_version = container_project.ext_management_system.api_version
    client = container_project.ext_management_system.connect_client(api_version, method)
    response = client.send(method, name, namespace)
  rescue KubeException => e
    if e.error_code == 404
      return nil
    end
    raise
  else
    response.to_h
  end

  def update_in_provider(resource)
    method = "update_#{entity_by_resource(self.class.name)}"
    api_version = container_project.ext_management_system.api_version
    client = container_project.ext_management_system.connect_client(api_version, method)
    client.send(method, resource)
  end
end
