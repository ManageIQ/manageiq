module AnsibleAuthentications
  ANSIBLE_SECRET_KEY_TYPE = "ansible_secret_key".freeze
  ANSIBLE_RABBITMQ_TYPE   = "ansible_rabbitmq_auth".freeze
  ANSIBLE_ADMIN_TYPE      = "ansible_admin_password".freeze
  ANSIBLE_DATABASE_TYPE   = "ansible_database_password".freeze

  AUTHENTICATION_CLASS_BY_TYPE = {
    ANSIBLE_SECRET_KEY_TYPE => AuthToken,
    ANSIBLE_RABBITMQ_TYPE   => AuthUseridPassword,
    ANSIBLE_ADMIN_TYPE      => AuthUseridPassword,
    ANSIBLE_DATABASE_TYPE   => AuthUseridPassword
  }.freeze

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
    auth = authentication_for_type(ANSIBLE_SECRET_KEY_TYPE, "Ansible Secret Key")

    auth.auth_key = key
    auth.save!
  end

  def ansible_rabbitmq_authentication
    authentication_type(ANSIBLE_RABBITMQ_TYPE)
  end

  def set_ansible_rabbitmq_authentication(userid: "tower", password:)
    auth = authentication_for_type(ANSIBLE_RABBITMQ_TYPE, "Ansible Rabbitmq Authentication")

    auth.userid   = userid
    auth.password = password
    auth.save!
    auth
  end

  def ansible_admin_authentication
    authentication_type(ANSIBLE_ADMIN_TYPE)
  end

  def set_ansible_admin_authentication(userid: "admin", password:)
    auth = authentication_for_type(ANSIBLE_ADMIN_TYPE, "Ansible Admin Authentication")

    auth.userid   = userid
    auth.password = password
    auth.save!
    auth
  end

  def ansible_database_authentication
    authentication_type(ANSIBLE_DATABASE_TYPE)
  end

  def set_ansible_database_authentication(userid: "awx", password:)
    auth = authentication_for_type(ANSIBLE_DATABASE_TYPE, "Ansible Database Authentication")

    auth.userid   = userid
    auth.password = password
    auth.save!
    auth
  end

  private

  def authentication_for_type(auth_type, name)
    auth = authentication_type(auth_type)
    return auth if auth

    auth = AUTHENTICATION_CLASS_BY_TYPE[auth_type].new
    auth.name     = name
    auth.resource = self
    auth.authtype = auth_type
    auth
  end
end
