class MiqDatabase < ActiveRecord::Base
  REGISTRATION_DEFAULT_VALUES = {
    :registration_type   => "sm_hosted",
    :registration_server => "subscription.rhn.redhat.com"
  }.freeze

  include AuthenticationMixin
  include PasswordMixin

  virtual_has_many  :vmdb_tables

  encrypt_column  :csrf_secret_token
  encrypt_column  :session_secret_token

  validate :registration_server_url_is_valid
  validates_presence_of :session_secret_token, :csrf_secret_token, :update_repo_name

  default_values REGISTRATION_DEFAULT_VALUES

  #TODO: move hard-coded update information
  def self.cfme_package_name
    "cfme-appliance"
  end

  def self.postgres_package_name
    "postgresql92-postgresql-server"
  end

  def self.registration_default_values
    REGISTRATION_DEFAULT_VALUES
  end

  def self.registration_default_value_for_update_repo_name(type = "sm_hosted")
    case type
    when "rhn_satellite" then "rhel-x86_64-server-6-cf-me-3.2 rhel-x86_64-server-6-rhscl-1"
    else                      "cf-me-5.4-for-rhel-6-rpms rhel-server-rhscl-6-rpms"
    end
  end

  def update_repo_names
    update_repo_name.split
  end

  def self.seed
    if self.exists?
      self.first.lock do |db|
        db.session_secret_token ||= SecureRandom.hex(64)
        db.csrf_secret_token    ||= SecureRandom.hex(64)
        db.update_repo_name     ||= registration_default_value_for_update_repo_name
        db.save! if db.changed?
      end
    else
      self.create!(
        :session_secret_token => SecureRandom.hex(64),
        :csrf_secret_token    => SecureRandom.hex(64),
        :update_repo_name     => registration_default_value_for_update_repo_name
      )
    end
  end

  def name
    ActiveRecord::Base.connection.current_database
  end

  def size
    ActiveRecord::Base.connection.database_size name
  end

  def self.adapter
    @adapter ||= ActiveRecord::Base.connection.instance_variable_get("@config")[:adapter]
  end

  def self.postgres?
    adapter == "postgresql"
  end

  # virtual has_many
  def vmdb_tables
    VmdbTable.all
  end

  def verify_credentials(auth_type=nil, options={})
    return true if auth_type == :registration_http_proxy

    MiqTask.wait_for_taskid(RegistrationSystem.verify_credentials_queue).task_results if auth_type == :registration
  end

  private

  def registration_server_url_is_valid
    return if registration_type != "rhn_satellite"  # Only validating Satellite 5 URL
    errors.add(:registration_server, "expected https://server.example.com/XMLRPC") unless registration_server =~ %r{\Ahttps?://.+/XMLRPC\z}i
  end
end
