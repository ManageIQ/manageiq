# ContainerResourceParentMixin provides capabilities to container
# resources that provide hierarchical management to other container
# resources.  Objects using the ContainerResourceParentMixin shall be able to
# create resources.  For example, a ConatinerRoute exists in a ContainerProject.
# Therefore, the ContainerProject shall be able to create routes.  There are
# namesapced resources without matching service models, e.g. role bindings.  In
# this case, the update_in_provider method is available.
module ContainerResourceParentMixin
  extend ActiveSupport::Concern
  require 'json'

  def create_resource(resource)
    resource[:metadata][:namespace] = name
    resource[:apiVersion] = ext_management_system.api_version
    method_name = "create_#{resource[:kind].underscore}"
    api_version = ext_management_system.api_version
    client = ext_management_system.connect_client(api_version, method_name)
    client.send(method_name, resource)
  end

  def get_resource_by_name(resource_name, kind, namespace = name, api_version = 'v1')
    method_name = "get_#{kind.underscore}"
    api_version = ext_management_system.api_version
    client = ext_management_system.connect_client(api_version, method_name)
    response = client.send(method_name, resource_name, namespace)
  rescue KubeException => e
    if e.error_code == 404
      return nil
    end
    raise
  else
    response
  end

  # Updates the resource in provider.  This is a wholesale replace.  The
  # metadata/namespace is set to the name of this resource.
  def update_in_provider(resource, api_version = 'v1')
    resource[:metadata][:namespace] = name
    resource[:apiVersion] = ext_management_system.api_version
    method_name = "update_#{resource[:kind].underscore}"
    api_version = ext_management_system.api_version
    client = ext_management_system.connect_client(api_version, method_name)
    response = client.send(method_name, resource)
  rescue KubeException => e
    if e.error_code == 404
      return nil
    end
    raise
  else
    response
  end
end
