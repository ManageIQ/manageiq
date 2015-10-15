require 'linux_admin'
LinuxAdmin.logger = $log

module MiqServer::UpdateManagement
  extend ActiveSupport::Concern

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
    attempt_registration unless rhn_mirror?

    check_updates
  end

  def attempt_registration
    return unless register
    attach_products
    # HACK: #enable_repos is not always successful immediately after #attach_products, retry to ensure they are enabled.
    5.times { repos_enabled? ? break : enable_repos }
  end

  def register
    update_attributes(:upgrade_message => "registering")
    if LinuxAdmin::RegistrationSystem.registered?
      _log.info("Appliance already registered")
      update_attributes(:rh_registered => true)
    else
      _log.info("Registering appliance...")
      registration_type = MiqDatabase.first.registration_type

      registration_class = LinuxAdmin::SubscriptionManager

      # TODO: Prompt user for environment in UI for Satellite 6 registration, use default environment for now.
      registration_options = assemble_registration_options
      registration_options[:environment] = "Library" if registration_type == "rhn_satellite6"

      registration_class.register(registration_options)

      # HACK: RHN is slow at writing the systemid file, wait up to 30 seconds for it to appear
      30.times { File.exist?("/etc/sysconfig/rhn/systemid") ? break : (sleep 1) }

      # Reload the registration_type
      LinuxAdmin::RegistrationSystem.registration_type(true)

      update_attributes(:rh_registered => LinuxAdmin::RegistrationSystem.registered?)
    end

    if rh_registered?
      update_attributes(:upgrade_message => "registration successful")
      _log.info("Registration Successful")
    else
      update_attributes(:upgrade_message => "registration failed")
      _log.error("Registration Failed")
    end

    rh_registered?
  end

  def attach_products
    update_attributes(:upgrade_message => "attaching products")
    _log.info("Attaching products based on installed certificates")
    LinuxAdmin::RegistrationSystem.subscribe(assemble_registration_options)
  end

  def repos_enabled?
    enabled = LinuxAdmin::RegistrationSystem.enabled_repos
    if MiqDatabase.first.update_repo_names.all? { |desired| enabled.include?(desired) }
      _log.info("Desired update repository is enabled")
      update_attributes(:rh_subscribed => true, :upgrade_message => "registered")
      return true
    end
    false
  end

  def enable_repos
    MiqDatabase.first.update_repo_names.each do |repo|
      update_attributes(:upgrade_message => "enabling #{repo}")
      begin
        LinuxAdmin::RegistrationSystem.enable_repo(repo, assemble_registration_options)
      rescue AwesomeSpawn::CommandResultError
        update_attributes(:upgrade_message => "failed to enable #{repo}")
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

    _log.info("Checking for CFME updates...")
    check_cfme_version_available

    _log.info("Checking for updates... Complete")
  end

  def apply_updates
    check_updates
    return unless updates_available?

    import_gpg_certificates

    _log.info("Applying Updates, Services will restart when complete.")

    # MiqDatabase.cfme_package_name will update only the CFME package tree.  (Won't disturb the database)
    # "" will update everything
    packages_to_update = EvmDatabase.local? ? [MiqDatabase.cfme_package_name] : []
    LinuxAdmin::Yum.update(*packages_to_update)
  end

  private

  def check_platform_updates
    update_attributes(:updates_available => LinuxAdmin::Yum.updates_available?, :last_update_check => Time.now.utc)
  end

  def check_postgres_updates
    MiqDatabase.first.update_attributes(:postgres_update_available => LinuxAdmin::Yum.updates_available?(MiqDatabase.postgres_package_name))
  end

  def check_cfme_version_available
    cfme = MiqDatabase.cfme_package_name
    MiqDatabase.first.update_attributes(:cfme_version_available => LinuxAdmin::Yum.version_available(cfme)[cfme])
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
