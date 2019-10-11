class AuthToken < Authentication
  def self.display_name(number = 1)
    n_('Authentication Token', 'Authentication Tokens', number)
  end
end
