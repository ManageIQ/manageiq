require 'linux_admin'
LinuxAdmin.logger = $log

module MiqServer::UpdateManagement
  extend ActiveSupport::Concern

  UPDATE_FILE = Rails.root.join("tmp/miq_update").freeze

  module ClassMethods
    def queue_update_registration_status(*ids)
      where(:id => ids.flatten).each(&:queue_update_registration_status)
    end

    def queue_check_updates(*ids)
      ids     = [MiqServer.my_server.id] if ids.blank?
      where(:id => ids.flatten).each(&:queue_check_updates)
    end

    def queue_apply_updates(*ids)
      where(:id => ids.flatten).each(&:queue_apply_updates)
    end
  end

  def queue_update_registration_status
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "update_registration_status",
      :server_guid => guid,
      :zone        => my_zone
    )
  end

  def queue_check_updates
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "check_updates",
      :server_guid => guid,
      :zone        => my_zone
    )
  end

  def queue_apply_updates
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "apply_updates",
      :server_guid => guid,
      :zone        => my_zone
    )
  end

  def update_registration_status
    attempt_registration

    check_updates
  end

  def attempt_registration
    return unless register
    attach_products
    configure_yum_proxy
    # HACK: #enable_repos is not always successful immediately after #attach_products, retry to ensure they are enabled.
    5.times { repos_enabled? ? break : enable_repos }
    update(:upgrade_message => "Registration process completed successfully")
    _log.info("Registration process completed successfully")
  rescue LinuxAdmin::SubscriptionManagerError => e
    _log.error("Registration Failed: #{e.message}")
    Notification.create(:type => "server_registration_error", :options => {:server_name => MiqServer.my_server.name})
    raise
  end

  def register
    update(:upgrade_message => "registering")
    if LinuxAdmin::SubscriptionManager.registered?(assemble_registration_options)
      _log.info("Appliance already registered")
      update(:rh_registered => true)
    else
      _log.info("Registering appliance...")
      registration_type = MiqDatabase.first.registration_type

      # TODO: Prompt user for environment in UI for Satellite 6 registration, use default environment for now.
      registration_options = assemble_registration_options
      registration_options[:environment] = "Library" if registration_type == "rhn_satellite6"

      LinuxAdmin::SubscriptionManager.register(registration_options)

      # Reload the registration_type
      LinuxAdmin::SubscriptionManager.registration_type(true)

      update(:rh_registered => LinuxAdmin::SubscriptionManager.registered?(assemble_registration_options))
    end

    if rh_registered?
      update(:upgrade_message => "registration successful")
      _log.info("Registration Successful")
    else
      update(:upgrade_message => "registration failed")
      _log.error("Registration Failed")
    end

    rh_registered?
  end

  def attach_products
    update(:upgrade_message => "attaching products")
    _log.info("Attaching products based on installed certificates")
    LinuxAdmin::SubscriptionManager.subscribe(assemble_registration_options)
  end

  def configure_yum_proxy
    registration_options = assemble_registration_options
    return unless registration_options[:proxy_address]
    conf = IniFile.load("/etc/yum.conf")
    conf["main"]["proxy"] = registration_options[:proxy_address]
    conf["main"]["proxy_username"] = registration_options[:proxy_username] if registration_options[:proxy_username]
    conf["main"]["proxy_password"] = registration_options[:proxy_password] if registration_options[:proxy_password]
    conf.save
  end

  def repos_enabled?
    enabled = LinuxAdmin::SubscriptionManager.enabled_repos
    if MiqDatabase.first.update_repo_names.all? { |desired| enabled.include?(desired) }
      _log.info("Desired update repository is enabled")
      update(:rh_subscribed => true, :upgrade_message => "registered")
      return true
    end
    false
  end

  def enable_repos
    MiqDatabase.first.update_repo_names.each do |repo|
      update(:upgrade_message => "enabling #{repo}")
      begin
        LinuxAdmin::SubscriptionManager.enable_repo(repo, assemble_registration_options)
      rescue AwesomeSpawn::CommandResultError
        update(:upgrade_message => "failed to enable #{repo}")
        Notification.create(:type => "enable_update_repo_failed", :options => {:repo_name => repo})
      end
    end
  end

  def cfme_available_update
    version_available = parse_product_version_number(MiqDatabase.first.cfme_version_available)
    version_running   = parse_product_version_number(MiqServer.my_server.version)

    version_available.keys.each do |version_component|
      if version_available[version_component].to_i > version_running[version_component].to_i
        return version_component.to_s
      end
    end

    nil
  end

  def check_updates
    _log.info("Checking for platform updates...")
    check_platform_updates

    _log.info("Checking for postgres updates...")
    check_postgres_updates

    _log.info("Checking for %{product} updates..." % {:product => Vmdb::Appliance.PRODUCT_NAME})
    check_cfme_version_available

    _log.info("Checking for updates... Complete")
  end

  def apply_updates
    check_updates
    return unless updates_available?

    import_gpg_certificates

    _log.info("Applying Updates, Services will restart when complete.")

    # MiqDatabase.cfme_package_name will update only the ManageIQ package tree.  (Won't disturb the database)
    # "" will update everything
    packages_to_update = EvmDatabase.local? ? [MiqDatabase.cfme_package_name] : []
    File.write(UPDATE_FILE, packages_to_update.join(" "))
  end

  private

  def check_platform_updates
    update(:updates_available => LinuxAdmin::Yum.updates_available?, :last_update_check => Time.now.utc)
  end

  def check_postgres_updates
    MiqDatabase.first.update(:postgres_update_available => LinuxAdmin::Yum.updates_available?(MiqDatabase.postgres_package_name))
  end

  def check_cfme_version_available
    cfme = MiqDatabase.cfme_package_name
    MiqDatabase.first.update(:cfme_version_available => LinuxAdmin::Yum.version_available(cfme)[cfme])
  end

  def assemble_registration_options
    db = MiqDatabase.first
    options = {}
    options[:username],       options[:password]       = db.auth_user_pwd(:registration)
    options[:proxy_username], options[:proxy_password] = db.auth_user_pwd(:registration_http_proxy)
    options[:org]                                      = db.registration_organization
    options[:proxy_address]                            = db.registration_http_proxy_server
    options[:server_url]                               = db.registration_server

    options.delete_blanks
  end

  def import_gpg_certificates
    files = File.join("/etc/pki/rpm-gpg/**", "{RPM-GPG-KEY-*}")
    Dir.glob(files).each { |key| LinuxAdmin::Rpm.import_key(key) }
  end

  def parse_product_version_number(version)
    return {} if version.blank?

    Hash[[:major, :minor, :maintenance, :build].zip(version.split("."))]
  end
end
