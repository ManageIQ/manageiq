class AuthToken < Authentication
  def auth_key=(val)
    @auth_changed = true if val != auth_key
    super(val)
  end

  def self.display_name(number = 1)
    n_('Authentication Token', 'Authentication Tokens', number)
  end
end
