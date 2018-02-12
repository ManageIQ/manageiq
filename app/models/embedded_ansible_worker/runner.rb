class EmbeddedAnsibleWorker::Runner < MiqWorker::Runner
  def prepare
    ObjectSpace.garbage_collect
    # Overriding prepare so we can set started when we're ready
    do_before_work_loop
    started_worker_record
    self
  end

  def do_before_work_loop
    raise_role_notification(:role_activate_start)
    setup_ansible
    update_embedded_ansible_provider
    raise_role_notification(:role_activate_success)
  rescue => err
    _log.log_backtrace(err)
    do_exit(err.message, 1)
  end

  def heartbeat
    super if embedded_ansible.alive?
  end

  def do_work
    embedded_ansible.start if !embedded_ansible.alive? && !embedded_ansible.running?
    provider.authentication_check if embedded_ansible.alive? && !provider.authentication_status_ok?
  end

  def before_exit(*_)
    embedded_ansible.disable
  end

  def setup_ansible
    _log.info("Starting embedded ansible service ...")
    embedded_ansible.start
    _log.info("Finished starting embedded ansible service.")
  end

  def update_embedded_ansible_provider
    server   = MiqServer.my_server(true)

    provider.name = "Embedded Ansible"
    provider.zone = server.zone
    provider.url  = provider_url
    provider.verify_ssl = 0

    provider.save!

    api_connection = embedded_ansible.api_connection
    worker.remove_demo_data(api_connection)
    worker.ensure_initial_objects(provider, api_connection)

    admin_auth = MiqDatabase.first.ansible_admin_authentication

    provider.update_authentication(:default => {:userid => admin_auth.userid, :password => admin_auth.password})
    provider.authentication_check
  end

  # Base class methods we override since we don't have a separate process.  We might want to make these opt-in features in the base class that this subclass can choose to opt-out.
  def set_process_title; end
  def set_database_application_name; end
  def set_connection_pool_size; end
  def message_sync_active_roles(*_args); end
  def message_sync_config(*_args); end

  private

  def provider
    @provider ||= ManageIQ::Providers::EmbeddedAnsible::Provider.first_or_initialize
  end

  def provider_url
    URI::Generic.build(provider_uri_hash).to_s
  end

  def provider_uri_hash
    if MiqEnvironment::Command.is_container?
      {:scheme => "https", :host => ContainerEmbeddedAnsible::ANSIBLE_SERVICE_NAME, :path => "/api/v1"}
    elsif Rails.env.development?
      {:scheme => "http", :host => "localhost", :path => "/api/v1", :port => 54321}
    else
      server = MiqServer.my_server(true)
      {:scheme => "https", :host => server.hostname || server.ipaddress, :path => "/ansibleapi/v1"}
    end
  end

  def raise_role_notification(notification_type)
    notification_options = {
      :role_name   => ServerRole.find_by(:name => worker.class.required_roles.first).description,
      :server_name => MiqServer.my_server.name
    }
    Notification.create(:type => notification_type, :options => notification_options)
  end

  def embedded_ansible
    @embedded_ansible ||= EmbeddedAnsible.new
  end
end
