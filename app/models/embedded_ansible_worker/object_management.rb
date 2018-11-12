module EmbeddedAnsibleWorker::ObjectManagement
  extend ActiveSupport::Concern

  def ensure_initial_objects(provider, connection)
    ensure_organization(provider, connection)
    ensure_credential(provider, connection)
    ensure_inventory(provider, connection)
    ensure_host(provider, connection)
    ensure_plugin_playbooks_project_seeded(provider, connection)
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
      :name        => Vmdb::Appliance.PRODUCT_NAME,
      :description => "#{Vmdb::Appliance.PRODUCT_NAME} Default Organization"
    ).id
  end

  def ensure_credential(provider, connection)
    return if provider.default_credential

    provider.default_credential = connection.api.credentials.create!(
      :name         => "#{Vmdb::Appliance.PRODUCT_NAME} Default Credential",
      :kind         => "ssh",
      :organization => provider.default_organization
    ).id
  end

  def ensure_inventory(provider, connection)
    return if provider.default_inventory

    provider.default_inventory = connection.api.inventories.create!(
      :name         => "#{Vmdb::Appliance.PRODUCT_NAME} Default Inventory",
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

  def ensure_plugin_playbooks_project_seeded(provider, connection)
    ea = EmbeddedAnsible.new
    return unless ea.respond_to?(:create_local_playbook_repo)

    ea.create_local_playbook_repo

    project = find_default_project(connection, provider.default_project)
    if project
      update_playbook_project(project, provider.default_organization)
    else
      provider.default_project = create_playbook_project(connection, provider.default_organization).id
    end
    # Note, we don't remove the temporary directory CONSOLIDATED_PLUGIN_PLAYBOOKS_TEMPDIR here because
    # 1) It shouldn't use too much disk space
    # 2) There isn't a synchronous way to import the git project into ansible so we'd need to poll ansible
    # and remove it AFTER it was cloned.
  end

  private

  def find_default_project(connection, project_id)
    return unless project_id
    connection.api.projects.find(project_id)
  rescue AnsibleTowerClient::ResourceNotFoundError
    nil
  end

  def update_playbook_project(project, organization)
    project.update_attributes!(self.class.playbook_project_attributes.merge(:organization => organization))
  end

  def create_playbook_project(connection, organization)
    connection.api.projects.create!(self.class.playbook_project_attributes.merge(:organization => organization).to_json)
  end

  class_methods do
    def consolidated_plugin_directory
      EmbeddedAnsible.new.playbook_repo_path
    end

    def playbook_project_attributes
      {
        :name                 => "#{Vmdb::Appliance.PRODUCT_NAME} Default Project".freeze,
        :scm_type             => "git".freeze,
        :scm_url              => "file://#{consolidated_plugin_directory}".freeze,
        :scm_update_on_launch => false
      }.freeze
    end
  end
end
