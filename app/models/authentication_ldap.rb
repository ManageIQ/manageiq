class AuthenticationLdap < Authentication

  def generate_ansible_entry
    options = {}
    options["attributes"] = {}
    options["attributes"]["id"] = ldap_id
    options["attributes"]["email"] = ldap_email
    options["attributes"]["name"] = ldap_name
    options["attributes"]["preferredUsername"] = ldap_preferred_user_name
    options["bindDN"] = ldap_bind_dn
    options["bindPassword"] = password_encrypted
    options["ca"] = certificate_authority
    options["insecure"] = ldap_insecure.to_s
    options["url"] = ldap_url
    ansible_format options
  end

  def ansible_config_format
    options = {}
    options["attributes"] = {}
    options["attributes"]["id"] = ldap_id
    options["attributes"]["email"] = ldap_email
    options["attributes"]["name"] = ldap_name
    options["attributes"]["preferredUsername"] = ldap_preferred_user_name
    options["bindDN"] = ldap_bind_dn
    options["bindPassword"] = password_encrypted
    options["ca"] = certificate_authority
    options["insecure"] = ldap_insecure.to_s
    options["url"] = ldap_url
    ansible_config options
  end
end
