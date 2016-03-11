class ManageIQ::Providers::AnsibleTower::Provider < ::Provider
  has_one :configuration_manager,
          :foreign_key => "provider_id",
          :class_name  => "ManageIQ::Providers::AnsibleTower::ConfigurationManager",
          :dependent   => :destroy,
          :autosave    => true

  has_many :endpoints, :as => :resource, :dependent => :destroy, :autosave => true

  delegate :url,
           :url=,
           :to => :default_endpoint

  virtual_column :url, :type => :string, :uses => :endpoints

  before_validation :ensure_managers

  validates :name, :presence => true, :uniqueness => true
  validates :url,  :presence => true, :uniqueness => true

  def self.raw_connect(base_url, username, password, verify_ssl)
    require 'ansible_tower_client'
    AnsibleTowerClient.logger ||= $log
    AnsibleTowerClient::Connection.new(
      :base_url   => base_url,
      :username   => username,
      :password   => password,
      :verify_ssl => verify_ssl
    )
  end

  def connect(options = {})
    auth_type = options[:auth_type]
    raise "no credentials defined" if self.missing_credentials?(auth_type) && (options[:username].nil? || options[:password].nil?)

    verify_ssl = options[:verify_ssl] || self.verify_ssl
    base_url   = options[:base_url] || url
    username   = options[:username] || authentication_userid(auth_type)
    password   = options[:password] || authentication_password(auth_type)

    self.class.raw_connect(base_url, username, password, verify_ssl)
  end

  def verify_credentials(auth_type = nil, options = {})
    validity = with_provider_connection(options.merge(:auth_type => auth_type), &:verify_credentials)
    raise MiqException::MiqInvalidCredentialsError, "Username or password is not valid" if validity.nil?
    validity
  rescue Faraday::ConnectionFailed, Faraday::SSLError => err
    raise MiqException::MiqUnreachableError, err.message, err.backtrace
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

  private

  def ensure_managers
    build_configuration_manager unless configuration_manager
    configuration_manager.name    = "#{name} Configuration Manager"
    configuration_manager.zone_id = zone_id
  end
end
