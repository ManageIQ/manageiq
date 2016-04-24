class AuthenticationHtpasswd < Authentication

  def generate_ansible_entry
    ansible_format
  end

  def ansible_config_format
    ansible_config(:filename => "/etc/origin/master/htpasswd")
  end

  def assign_values(options)
    hash = {}
    hash["htpassd_users"] = {options["username"]  => options["password"]}
    super hash
  end

end
