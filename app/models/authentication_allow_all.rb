class AuthenticationAllowAll < Authentication

  #will be removed once moving to yaml format
  def generate_ansible_entry
    ansible_format
  end

  def ansible_config_format
    ansible_config
  end

  def assign_values(options)
    super
  end
end
