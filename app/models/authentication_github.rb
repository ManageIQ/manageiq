class AuthenticationGithub < Authentication

  #will be removed once moving to yaml format, no need to review method
  def generate_ansible_entry
    options = {}
    options["clientID"] = userid
    options["clientSecret"] = password
    options["challenge"] = "false"
    options["github_organizations"] = github_organizations
    ansible_format options
  end

  def ansible_config_format
    options = {}
    options["clientID"] = userid
    options["clientSecret"] = password
    options["challenge"] = "false"
    options["github_organizations"] = github_organizations if github_organizations
    ansible_config options
  end
end
