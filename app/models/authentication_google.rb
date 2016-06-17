class AuthenticationGoogle < Authentication

  #will be removed once moving to yaml format, no need to review method
  def generate_ansible_entry
    options = {}
    options["clientID"] = userid
    options["clientSecret"] = password
    options["hostedDomain"] = google_hosted_domain
    options["challenge"] = "false"
    ansible_format options
  end

  def ansible_config_format
    options = {}
    options["clientID"] = userid
    options["clientSecret"] = password
    options["hostedDomain"] = google_hosted_domain
    options["challenge"] = "false"
    ansible_config options
  end
end
