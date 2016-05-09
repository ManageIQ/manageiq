class AuthenticationGithub < Authentication

  def generate_ansible_entry
    options = {}
    options["clientID"] = userid
    options["clientSecret"] = password_encrypted
    options["challenge"] = "false"
    options["github_organizations"] = github_organizations
    ansible_format options
  end

  def ansible_config_format
    options = {}
    options["clientID"] = userid
    options["clientSecret"] = password_encrypted
    options["challenge"] = "false"
    options["github_organizations"] = github_organizations if github_organizations
    ansible_format options
  end

  def assign_values(options)
    hash = {}
    hash["password"] = options["clientSecret"]
    hash["userid"] = options["clientId"]
    super hash
  end
end
