require 'linux_admin'

module RegistrationSystem
  RHSM_CONFIG_FILE = "/etc/rhsm/rhsm.conf".freeze

  def self.available_organizations_queue(options = {})
    options = options.clone
    options[:password] = ManageIQ::Password.try_encrypt(options[:password])
    options[:registration_http_proxy_password] = ManageIQ::Password.try_encrypt(options[:registration_http_proxy_password])

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
    options[:password] = ManageIQ::Password.try_encrypt(options[:password])
    options[:registration_http_proxy_password] = ManageIQ::Password.try_encrypt(options[:registration_http_proxy_password])

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

  def self.update_rhsm_conf_queue(options = {})
    options = options.dup
    options[:password] = ManageIQ::Password.try_encrypt(options[:password])
    options[:registration_http_proxy_password] = ManageIQ::Password.try_encrypt(options[:registration_http_proxy_password])
    options.delete_blanks

    task_opts = {
      :action => "Update Rhsm Config",
      :userid => "system"
    }

    MiqRegion.my_region.miq_servers.each do |server|
      queue_opts = {
        :class_name  => "RegistrationSystem",
        :method_name => "update_rhsm_conf",
        :priority    => MiqQueue::HIGH_PRIORITY,
        :args        => options,
        :server_guid => server.guid
      }

      MiqTask.generic_action_with_callback(task_opts, queue_opts)
    end
  end

  def self.available_organizations(options = {})
    raw_values = LinuxAdmin::SubscriptionManager.new.organizations(assemble_options(options)).values
    raw_values.each_with_object({}) { |v, h| h[v[:name]] = v[:key] }
  end

  def self.verify_credentials(options = {})
    LinuxAdmin::SubscriptionManager.validate_credentials(assemble_options(options))
  rescue NotImplementedError, LinuxAdmin::CredentialError
    false
  end

  def self.update_rhsm_conf(options = {})
    option_values = assemble_options(options)

    return unless option_values[:proxy_address]

    proxy_uri = URI.parse(option_values[:proxy_address].include?("://") ? option_values[:proxy_address] : "http://#{option_values[:proxy_address]}")
    write_rhsm_config(:proxy_hostname => proxy_uri.host,
                      :proxy_port     => proxy_uri.port,
                      :proxy_user     => option_values[:proxy_username],
                      :proxy_password => option_values[:proxy_password])
  end

  def self.assemble_options(options)
    options = database_options if options.blank?
    {
      :username          => options[:userid],
      :password          => ManageIQ::Password.try_decrypt(options[:password]),
      :server_url        => options[:registration_server],
      :registration_type => options[:registration_type],
      :proxy_address     => options[:registration_http_proxy_server],
      :proxy_username    => options[:registration_http_proxy_username],
      :proxy_password    => ManageIQ::Password.try_decrypt(options[:registration_http_proxy_password]),
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

  def self.write_rhsm_config(params)
    FileUtils.copy(RHSM_CONFIG_FILE, "#{RHSM_CONFIG_FILE}.miq_orig") unless File.exist?("#{RHSM_CONFIG_FILE}.miq_orig")
    rhsm_config = File.read(RHSM_CONFIG_FILE)
    rhsm_config[/\s*proxy_hostname\s*=(.*)/, 1] = " #{params[:proxy_hostname]}"
    rhsm_config[/\s*proxy_port\s*=(.*)/, 1]     = " #{params[:proxy_port]}"
    rhsm_config[/\s*proxy_user\s*=(.*)/, 1]     = " #{params[:proxy_user]}"
    rhsm_config[/\s*proxy_password\s*=(.*)/, 1] = " #{params[:proxy_password]}"
    File.write(RHSM_CONFIG_FILE, rhsm_config)
  end
  private_class_method :write_rhsm_config
end
