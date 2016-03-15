class ManageIQ::Providers::Foreman::Provider < ::Provider
  has_one :configuration_manager,
          :foreign_key => "provider_id",
          :class_name  => "ManageIQ::Providers::Foreman::ConfigurationManager",
          :dependent   => :destroy,
          :autosave    => true
  has_one :provisioning_manager,
          :foreign_key => "provider_id",
          :class_name  => "ManageIQ::Providers::Foreman::ProvisioningManager",
          :dependent   => :destroy,
          :autosave    => true

  has_many :endpoints, :as => :resource, :dependent => :destroy, :autosave => true

  delegate :url,
           :url=,
           :to => :default_endpoint

  virtual_column :url, :type => :string, :uses => :endpoints

  delegate :api_cached?, :ensure_api_cached, :to => :connect

  before_validation :ensure_managers

  validates :name, :presence => true, :uniqueness => true
  validates :url,  :presence => true, :uniqueness => true

  def self.raw_connect(base_url, username, password, verify_ssl)
    require 'manageiq_foreman'
    ManageiqForeman.logger ||= $log
    ManageiqForeman::Connection.new(
      :base_url   => base_url,
      :username   => username,
      :password   => password,
      :verify_ssl => verify_ssl
    )
  end

  def connect(options = {})
    auth_type = options[:auth_type]
    raise "no credentials defined" if self.missing_credentials?(auth_type)

    verify_ssl = options[:verify_ssl] || self.verify_ssl
    base_url   = options[:url] || url
    username   = options[:username] || authentication_userid(auth_type)
    password   = options[:password] || authentication_password(auth_type)

    self.class.raw_connect(base_url, username, password, verify_ssl)
  end

  def verify_credentials(auth_type = nil, options = {})
    with_provider_connection(options.merge(:auth_type => auth_type), &:verify?)
  rescue SocketError,
         Errno::ECONNREFUSED,
         RestClient::ResourceNotFound,
         RestClient::InternalServerError => err
    raise MiqException::MiqUnreachableError, err.message, err.backtrace
  rescue RestClient::Unauthorized => err
    raise MiqException::MiqInvalidCredentialsError, err.message, err.backtrace
  end

  private

  def ensure_managers
    build_provisioning_manager unless provisioning_manager
    provisioning_manager.name    = "#{name} Provisioning Manager"
    provisioning_manager.zone_id = zone_id

    build_configuration_manager unless configuration_manager
    configuration_manager.name    = "#{name} Configuration Manager"
    configuration_manager.zone_id = zone_id
  end

  def self.process_tasks(options)
    raise "No ids given to process_tasks" if options[:ids].blank?
    if options[:task] == "refresh_ems"
      refresh_ems(options[:ids])
      create_audit_event(options)
    else
      options[:userid] ||= "system"
      unknown_task_exception(options)
      invoke_tasks_queue(options)
    end
  end

  def self.create_audit_event(options)
    msg = "'%{task}' initiated for %{amount} %{providers}" % {
      :task      => options[:task],
      :amount    => options[:ids].length,
      :providers => Dictionary.gettext('providers',
                                       :type      => :table,
                                       :notfound  => :titleize,
                                       :plural    => options[:ids].length > 1,
                                       :translate => false)}
    AuditEvent.success(:event        => options[:task],
                       :target_class => base_class.name,
                       :userid       => options[:userid],
                       :message      => msg)
  end

  def self.unknown_task_exception(options)
    raise "Unknown task, #{options[:task]}" unless instance_methods.collect(&:to_s).include?(options[:task])
  end

  def self.refresh_ems(provider_ids)
    EmsRefresh.queue_refresh(Array.wrap(provider_ids).collect { |id| [base_class, id] })
  end
end
