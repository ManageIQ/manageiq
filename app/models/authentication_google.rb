class AuthenticationGoogle < Authentication

  def generate_ansible_entry
    options = {}
    options["clientID"] = userid
    options["clientSecret"] = password_encrypted
    options["hostedDomain"] = google_hosted_domain
    options["challenge"] = "false"
    options["open_id_extra_authorize_parameters"] = open_id_extra_authorize_parameters
    options["open_id_extra_scopes"] = open_id_extra_scopes
    ansible_format options
  end

  def ansible_config_format
    options = {}
    options["clientID"] = userid
    options["clientSecret"] = password_encrypted
    options["hostedDomain"] = google_hosted_domain
    options["challenge"] = "false"
    options["open_id_extra_authorize_parameters"] = open_id_extra_authorize_parameters
    options["open_id_extra_scopes"] = open_id_extra_scopes
    ansible_config options
  end

  def assign_values(options)
    hash = {}
    hash["password"] = options["clientSecret"]
    hash["google_hosted_domain"] = options["hostedDomain"]
    hash["userid"] = options["clientId"]
    super hash
  end
end
