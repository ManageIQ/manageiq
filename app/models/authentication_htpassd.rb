class AuthenticationHtpassd < Authentication

  def generate_ansible_entry

    ansible_format
  end

  def ansible_config_format
    ansible_config(:filename => "/etc/origin/master/htpasswd")
  end
end
