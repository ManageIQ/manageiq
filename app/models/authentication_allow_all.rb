class AuthenticationAllowAll < Authentication

  def generate_ansible_entry
    ansible_format
  end

  def ansible_config_format
    ansible_config
  end
end
