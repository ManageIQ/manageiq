module AnsibleAuthentications
  ANSIBLE_SECRET_KEY_TYPE = "ansible_secret_key".freeze
  ANSIBLE_RABBITMQ_TYPE   = "ansible_rabbitmq_auth".freeze
  ANSIBLE_ADMIN_TYPE      = "ansible_admin_password".freeze
  ANSIBLE_DATABASE_TYPE   = "ansible_database_password".freeze

  def self.included(base)
    base.class_eval do
      include AuthenticationMixin
    end
  end

  def ansible_secret_key
    auth = authentication_type(ANSIBLE_SECRET_KEY_TYPE)
    auth.nil? ? nil : auth.auth_key
  end

  def ansible_secret_key=(key)
    auth = authentication_type(ANSIBLE_SECRET_KEY_TYPE)
    auth ||= AuthToken.new(
      :name     => "Ansible Secret Key",
      :resource => self,
      :authtype => ANSIBLE_SECRET_KEY_TYPE
    )

    auth.auth_key = key
    auth.save!
  end

  def ansible_rabbitmq_password
    auth = authentication_type(ANSIBLE_RABBITMQ_TYPE)
    auth.nil? ? nil : auth.password
  end

  def ansible_rabbitmq_password=(password)
    auth = authentication_type(ANSIBLE_RABBITMQ_TYPE)
    auth ||= AuthUseridPassword.new(
      :userid   => "tower",
      :name     => "Ansible Rabbitmq Auth",
      :resource => self,
      :authtype => ANSIBLE_RABBITMQ_TYPE
    )

    auth.password = password
    auth.save!
  end

  def ansible_admin_password
    auth = authentication_type(ANSIBLE_ADMIN_TYPE)
    auth.nil? ? nil : auth.password
  end

  def ansible_admin_password=(password)
    auth = authentication_type(ANSIBLE_ADMIN_TYPE)
    auth ||= AuthUseridPassword.new(
      :userid   => "admin",
      :name     => "Ansible Admin Password",
      :resource => self,
      :authtype => ANSIBLE_ADMIN_TYPE
    )

    auth.password = password
    auth.save!
  end

  def ansible_database_password
    auth = authentication_type(ANSIBLE_DATABASE_TYPE)
    auth.nil? ? nil : auth.password
  end

  def ansible_database_password=(password)
    auth = authentication_type(ANSIBLE_DATABASE_TYPE)
    auth ||= AuthUseridPassword.new(
      :userid   => "awx",
      :name     => "Ansible Database Password",
      :resource => self,
      :authtype => ANSIBLE_DATABASE_TYPE
    )

    auth.password = password
    auth.save!
  end
end
