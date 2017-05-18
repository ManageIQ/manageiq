module EmbeddedAnsibleWorker::ObjectManagement
  extend ActiveSupport::Concern

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

    provider.default_organization = connection.api.organizations.create!(
      :name        => I18n.t("product.name"),
      :description => "#{I18n.t("product.name")} Default Organization"
    ).id
  end

  def ensure_credential(provider, connection)
    return if provider.default_credential

    provider.default_credential = connection.api.credentials.create!(
      :name         => "#{I18n.t("product.name")} Default Credential",
      :kind         => "ssh",
      :organization => provider.default_organization
    ).id
  end

  def ensure_inventory(provider, connection)
    return if provider.default_inventory

    provider.default_inventory = connection.api.inventories.create!(
      :name         => "#{I18n.t("product.name")} Default Inventory",
      :organization => provider.default_organization
    ).id
  end

  def ensure_host(provider, connection)
    return if provider.default_host

    provider.default_host = connection.api.hosts.create!(
      :name      => "localhost",
      :inventory => provider.default_inventory,
      :variables => {'ansible_connection' => "local"}.to_yaml
    ).id
  end
end
