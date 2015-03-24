class HostOpenstackInfra < Host
  belongs_to :availability_zone

  # TODO(lsmola) for some reason UI can't handle joined table cause there is hardcoded somewhere that it selects
  # DISTINCT id, with joined tables, id needs to be prefixed with table name. When this is figured out, replace
  # cloud tenant with rails relations
  # has_many :vms, :class_name => 'VmOpenstack', :foreign_key => :host_id
  # has_many :cloud_tenants, :through => :vms, :uniq => true

  def cloud_tenants
    CloudTenant.where(:id => vms.collect(&:cloud_tenant_id).uniq)
  end

  def ssh_users_and_passwords
    # HostOpenstackInfra is using auth key set on ext_management_system level, not individual hosts
    rl_user, auth_key = self.auth_user_keypair(:ssh_keypair)
    rl_password = nil

    # TODO(lsmola) make sudo user work. So it with be optional sudo password for private key auth, also test
    # password-less sudo
    su_user, su_password = nil, nil

    return rl_user, rl_password, su_user, su_password, {:key_data => auth_key}
  end

  def auth_user_keypair(type = nil)
    # HostOpenstackInfra is using auth key set on ext_management_system level, not individual hosts
    cred = self.try(:ext_management_system).try(:authentication_best_fit, type)
    return nil if cred.nil? || cred.userid.blank?
    [cred.userid, cred.auth_key]
  end
end
