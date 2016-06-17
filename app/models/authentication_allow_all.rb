class AuthenticationAllowAll < Authentication

  #will be removed once moving to yaml format, no need to review method
  def generate_ansible_entry
    ansible_format
  end

  def ansible_config_format
    ansible_config
  end

end
