class AuthenticationLdap < Authentication
  def assign_values(options)
    hash = {}
    options.each do |key, val|
      hash["ldap_" + key.to_s] = val
    end
    super(hash)
  end

  def self.display_name(number = 1)
    n_('Authentication (LDAP)', 'Authentications (LDAP)', number)
  end
end
