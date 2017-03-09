class EmbeddedAnsibleWorker::Runner < MiqWorker::Runner
  self.wait_for_worker_monitor = false

  def prepare
    ObjectSpace.garbage_collect
    # Overriding prepare so we can set started when we're ready
    do_before_work_loop
    started_worker_record
    self
  end

  def do_before_work_loop
    setup_ansible
    update_embedded_ansible_provider
  rescue => err
    _log.log_backtrace(err)
    do_exit(err.message, 1)
  end

  def heartbeat
    super if EmbeddedAnsible.alive?
  end

  def do_work
    EmbeddedAnsible.start if !EmbeddedAnsible.alive? && !EmbeddedAnsible.running?
  end

  def before_exit(*_)
    EmbeddedAnsible.disable
  end

  def setup_ansible
    _log.info("calling EmbeddedAnsible.configure")
    EmbeddedAnsible.configure unless EmbeddedAnsible.configured?

    _log.info("calling EmbeddedAnsible.start")
    EmbeddedAnsible.start
    _log.info("calling EmbeddedAnsible.start finished")
  end

  def update_embedded_ansible_provider
    server   = MiqServer.my_server(true)
    provider = ManageIQ::Providers::EmbeddedAnsible::Provider.first_or_initialize

    provider.name = "Embedded Ansible"
    provider.zone = server.zone
    provider.url  = URI::HTTPS.build(:host => server.hostname || server.ipaddress, :path => "/ansibleapi/v1").to_s
    provider.verify_ssl = 0

    provider.save!

    admin_auth = MiqDatabase.first.ansible_admin_authentication

    provider.update_authentication(:default => {:userid => admin_auth.userid, :password => admin_auth.password})
    provider.authentication_check
  end

  # Base class methods we override since we don't have a separate process.  We might want to make these opt-in features in the base class that this subclass can choose to opt-out.
  def set_process_title; end
  def set_connection_pool_size; end
  def message_sync_active_roles(*_args); end
  def message_sync_config(*_args); end
end
