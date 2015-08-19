class EmsAzure < EmsCloud
  alias_attribute :tenant_id, :uid_ems

  def self.ems_type
    @ems_type ||= "azure".freeze
  end

  def self.description
    @description ||= "Azure".freeze
  end

  def self.hostname_required?
    false
  end

  def self.raw_connect(clientid, clientkey, tenantid)
    Azure::Armrest::ArmrestManager.configure(
      :client_id  => clientid,
      :client_key => clientkey,
      :tenant_id  => tenantid
    )
  end

  def connect(options = {})
    raise "no credentials defined" if self.missing_credentials?(options[:auth_type])

    clientid  = options[:user] || authentication_userid(options[:auth_type])
    clientkey = options[:pass] || authentication_password(options[:auth_type])

    self.class.raw_connect(clientid, clientkey, tenant_id)
  end

  def verify_credentials(_auth_type = nil, _options = {})
    # TODO
    true
  end
end
