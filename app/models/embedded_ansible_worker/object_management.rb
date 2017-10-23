module EmbeddedAnsibleWorker::ObjectManagement
  extend ActiveSupport::Concern

  # This should not change as we match this to existing objects on the ansible side
  DEFAULT_NAME = "EVM".freeze

  def ensure_initial_objects(provider, connection)
    ensure_organization(provider, connection)
    ensure_credential(provider, connection)
    ensure_inventory(provider, connection)
    ensure_host(provider, connection)
  end

  def remove_demo_data(connection)
    connection.api.credentials.all(:name => "Demo Credential").each(&:destroy!)
    connection.api.inventories.all(:name => "Demo Inventory").each(&:destroy!)
    connection.api.job_templates.all(:name => "Demo Job Template").each(&:destroy!)
    connection.api.projects.all(:name => "Demo Project").each(&:destroy!)
    connection.api.organizations.all(:name => "Default").each(&:destroy!)
  end

  def ensure_organization(provider, connection)
    return if provider.default_organization
    attrs = default_organization_attributes

    provider.default_organization = find_or_create!(connection.api.organizations, attrs).id
  end

  def ensure_credential(provider, connection)
    return if provider.default_credential
    ensure_organization(provider, connection) unless provider.default_organization

    attrs = default_credential_attributes(provider.default_organization)

    provider.default_credential = find_or_create!(connection.api.credentials, attrs).id
  end

  def ensure_inventory(provider, connection)
    return if provider.default_inventory
    ensure_organization(provider, connection) unless provider.default_organization

    attrs = default_inventory_attributes(provider.default_organization)

    provider.default_inventory = find_or_create!(connection.api.inventories, attrs).id
  end

  def ensure_host(provider, connection)
    return if provider.default_host
    ensure_inventory(provider, connection) unless provider.default_inventory

    attrs = default_host_attributes(provider.default_inventory)

    provider.default_host = find_or_create!(connection.api.hosts, attrs).id
  end

  private

  def attributes_for_find(attrs)
    # It seems the matching for attributes doesn't really work
    # for YAML serialized data so we exclude the variables key here
    attrs.dup.delete_if { |k, _v| k == :variables }
  end

  def find_or_create!(collection, attrs)
    resources = collection.all(attributes_for_find(attrs))
    return resources.first unless resources.count.zero?

    collection.create!(attrs)
  end

  def default_organization_attributes
    {
      :name        => DEFAULT_NAME,
      :description => "#{DEFAULT_NAME} Default Organization"
    }
  end

  def default_credential_attributes(org_id)
    {
      :name         => "#{DEFAULT_NAME} Default Credential",
      :kind         => "ssh",
      :organization => org_id
    }
  end

  def default_inventory_attributes(org_id)
    {
      :name         => "#{DEFAULT_NAME} Default Inventory",
      :organization => org_id
    }
  end

  def default_host_attributes(inv_id)
    {
      :name      => "localhost",
      :inventory => inv_id,
      :variables => {'ansible_connection' => "local"}.to_yaml
    }
  end
end
