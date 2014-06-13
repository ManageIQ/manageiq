require 'linux_admin'

module RegistrationSystem
  def self.available_organizations_queue(options = {})
    options = options.clone
    options[:password] = MiqPassword.try_encrypt(options[:password])
    options[:registration_http_proxy_password] = MiqPassword.try_encrypt(options[:registration_http_proxy_password])

    task_opts = {
      :action => "Fetching Available Organizations",
      :userid => "system"
    }

    queue_opts = {
      :class_name  => "RegistrationSystem",
      :method_name => "available_organizations",
      :priority    => MiqQueue::HIGH_PRIORITY,
      :args        => [options.delete_blanks]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.verify_credentials_queue(options = {})
    options = options.clone
    options[:password] = MiqPassword.try_encrypt(options[:password])
    options[:registration_http_proxy_password] = MiqPassword.try_encrypt(options[:registration_http_proxy_password])

    task_opts = {
      :action => "Verifying Credentials",
      :userid => "system"
    }

    queue_opts = {
      :class_name  => "RegistrationSystem",
      :method_name => "verify_credentials",
      :priority    => MiqQueue::HIGH_PRIORITY,
      :args        => [options.delete_blanks]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.available_organizations(options = {})
    LinuxAdmin::SubscriptionManager.new.organizations(assemble_options(options)).keys
  end

  def self.verify_credentials(options = {})
    LinuxAdmin::RegistrationSystem.validate_credentials(assemble_options(options))
  rescue NotImplementedError, LinuxAdmin::CredentialError
    false
  end

  private

  def self.assemble_options(options)
    options = database_options if options.blank?
    {
      :username          => options[:userid],
      :password          => MiqPassword.try_decrypt(options[:password]),
      :server_url        => options[:registration_server],
      :registration_type => options[:registration_type],
      :proxy_address     => options[:registration_http_proxy_server],
      :proxy_username    => options[:registration_http_proxy_username],
      :proxy_password    => MiqPassword.try_decrypt(options[:registration_http_proxy_password]),
    }.delete_blanks
  end
  private_class_method :assemble_options

  def self.database_options
    db = MiqDatabase.first
    {
      :userid                           => db.authentication_userid(:registration),
      :password                         => db.authentication_password(:registration),
      :registration_server              => db.registration_server,
      :registration_type                => db.registration_type,
      :registration_http_proxy_server   => db.registration_http_proxy_server,
      :registration_http_proxy_username => db.authentication_userid(:registration_http_proxy),
      :registration_http_proxy_password => db.authentication_password(:registration_http_proxy),
    }
  end
  private_class_method :database_options
end